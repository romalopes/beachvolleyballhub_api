# Phase 5 — Turnstile, abuse protection, integration and release

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §6 (all), §9, §10, §11, §12
**Status:** Complete for code and documentation; production secrets and the
worker are operator steps listed in §7.

## 1. Delivered files

| File | Purpose |
|---|---|
| `app/services/turnstile_verifier.rb` | Server-side Siteverify with fail-closed policy |
| `test/services/turnstile_verifier_test.rb` | 13 examples (valid/invalid/expired/unavailable/disabled) |
| `config/initializers/rack_attack.rb` | Per-IP contact-form throttles |
| `app/controllers/api/v1/contact_messages_controller.rb` | Honeypot + Turnstile + validation ordering |
| `.env.example` (API + frontend) | Environment contract |
| `beachvolleyballhub_api/render.yaml` | Contact variables on the API web service and worker |
| `DEPLOYMENT_CONFIG.md` | Operator runbook for this feature |

## 2. Layered abuse protection

| Layer | Behaviour |
|---|---|
| **Rack::Attack** | `5` submissions per IP per 10 minutes and `20` per day on `POST /api/v1/contact_messages` (override with `CONTACT_RATE_LIMIT_PER_10_MINUTES` / `CONTACT_RATE_LIMIT_PER_DAY`). Uses the existing JSON 429 responder — generic message, no internal keys |
| **Cloudflare Turnstile** | Token verified server-side against Siteverify with `TURNSTILE_SECRET_KEY`, `remoteip`, and `action: "contact"`. Optional hostname allowlist via `TURNSTILE_EXPECTED_HOSTNAME` |
| **Honeypot** | `website` field: hidden from sight/AT, never focusable. Filled → **201 with the normal success body** and nothing persisted (bots learn nothing) |
| **Model validation** | Allowlisted category, lengths, e-mail format, control-character rejection |
| **Transport/limits** | JSON body parsed by Rails; only five attributes are permitted; Turnstile tokens, honeypot values and recipients are never stored |

## 3. Turnstile failure policy

| Situation | Result | HTTP |
|---|---|---|
| Key configured, token accepted | proceed | 201 / 422 from validation |
| Key configured, token rejected/missing/expired | `:invalid` | 422 generic "could not verify" |
| Key configured, provider error/timeout/non-2xx | `:unavailable` (**fail closed**) | 503 generic "temporarily unavailable" |
| No key, development/test | `:disabled` | proceeds (local only) |
| No key, **production** | `:unavailable` (**fail closed**, logged) | 503 |

The provider error codes are logged but never returned to the client. The
verifier accepts an injectable `http_class` and an explicit `production:` flag, so
every branch is unit-tested without network access.

## 4. Proxy and IP handling

`config/environments/production.rb` already extends
`ActionDispatch::RemoteIp::TRUSTED_PROXIES` with Cloudflare's CIDR ranges, so
`req.ip` (used by both Rack::Attack and the Turnstile `remoteip`) is resolved from
trusted hops only. No raw `X-Forwarded-For` value is trusted.

## 5. Privacy and logging

- Message bodies and visitor addresses are **not** written to logs. Log lines are
  keyed by record id and outcome only (`[contact] delivery failed for
  contact_message=…`, `[contact] submission discarded by honeypot`, …).
- The public API never returns recipients, ids, status or stack traces.
- No public route can read a message; the inbox lives under `/api/v1/admin` and is
  policy-gated.
- A message is never associated with a profile, account, organisation, training,
  tournament, assessment, analysis or location.

## 6. Regression checks performed

| Check | Result |
|---|---|
| Full API suite | `1928 runs, 7730 assertions, 0 errors, 2 pre-existing failures, 1 skip` (see §8) |
| Contact-specific API suite | `94 runs, 349 assertions, 0 failures` |
| Contact-specific frontend suite | `54 tests` across the new pages + sidebar, all passing |
| Frontend production build (`tsc -b && vite build`) | ✅ |
| ESLint | No errors in any file added or changed by this feature (13 pre-existing errors remain in unrelated files) |
| RuboCop on all new/changed API files | 17 files, no offenses |
| Existing notification, mail, auth and profile flows | untouched — see §7 |

## 7. What this feature did NOT change

- `MAIL_REPLY_TO` / `MailSender` / `MailTransport` semantics.
- `Notification`, `Notifications::Publisher` and existing event keys (one new
  `contact.message.received` type was added).
- Roles, `AdminAreaPolicy`, or any organisation/permission rule.
- Player/coach profile, training, tournament, assessment, analysis, location or
  weather behaviour — no code in those areas was modified.

## 8. Pre-existing failures observed (not caused by this feature)

| Test | Symptom |
|---|---|
| `Api::V1::HealthControllerTest#test_send_test_email_delivers_via_the_effective_transport…` | Expects transport `auto`, environment resolves `brevo` |
| `Public::WeatherSharesControllerTest#test_show_formats_selected_forecast_time_in_the_snapshot_timezone` | Rendered snapshot time differs from the expected string |
| `src/App.test.tsx` (8), `src/pages/Home.test.tsx` (2), `src/pages/TrainingFormPage.test.tsx` (9) | Verified identical with the feature's changes stashed (`git stash`) — `window.matchMedia` missing in jsdom and unrelated assertions |

## 9. Deployment runbook

### Cloudflare Turnstile

1. Create (or reuse) a Turnstile widget; add `beachvolleyballhub.com` and any
   staging hostname.
2. Site key → frontend build environment (`VITE_TURNSTILE_SITE_KEY`).
3. Secret key → **API only** (`TURNSTILE_SECRET_KEY`). Never in a `VITE_*` value.
4. Optionally set `TURNSTILE_EXPECTED_HOSTNAME` to enforce the hostname the token
   was solved on.
5. Confirm the API can reach `https://challenges.cloudflare.com` (Siteverify).

### Render (API + worker)

1. Set on the **API** service (`bvb-api`): `CONTACT_NOTIFICATION_EMAILS`,
   `TURNSTILE_SECRET_KEY` (+ optional `TURNSTILE_EXPECTED_HOSTNAME`,
   `CONTACT_RATE_LIMIT_*`). Mail settings (`MAIL_FROM`, `MAIL_REPLY_TO`,
   `BREVO_API_KEY`, `MAIL_TRANSPORT`) are unchanged.
2. Set `CONTACT_NOTIFICATION_EMAILS` on the **existing worker** (`bvb-api-worker`,
   `./bin/jobs`) and confirm it has the same mail settings as the web service.
   Verify it processes `ContactMessageDeliveryJob` after a submission.
3. Run the migration (the web service's `preDeployCommand` runs
   `bin/render-predeploy.sh`) — creates `contact_messages` only; no data
   migration.
4. Verify CORS still allows `https://beachvolleyballhub.com` and the API base URL
   points at `https://api.beachvolleyballhub.com`.
5. Set `VITE_TURNSTILE_SITE_KEY` in the frontend build environment and rebuild.

### Rollback

1. Hide the Contact link / route in a frontend release first (fastest, keeps data).
2. `contact_messages` is additive and backward compatible — **do not drop it**.
3. Rolling the API back leaves the table unused; re-deploying the previous
   frontend does the same.
4. Do not rotate or remove shared mail/Turnstile settings when rolling back: other
   mail flows depend on them.

### Operational monitoring

- `ContactMessage` counts and `status = unread` (inbox backlog).
- Solid Queue failed-job count for `ContactMessageDeliveryJob`.
- 429 rate from `POST /api/v1/contact_messages`.
- Log lines prefixed `[contact]` (delivery failures, honeypot discards, missing
  recipient configuration, Turnstile outages).

## 10. Manual staging walkthrough (from the plan §11)

1. Open the frontend in a private window → Contact appears in the public
   navigation.
2. Submit a valid general enquiry → success message; one `contact_messages` row.
3. Confirm every `CONTACT_NOTIFICATION_EMAILS` address received the email, that
   Reply-To is the visitor and From is the application sender.
4. Confirm platform Admins/Curators received the in-app notification (bell).
5. Sign in as a player → no Contact Messages link, and the API returns 403.
6. Sign in as a coach → same.
7. Sign in as a Curator → Settings → Contact Messages lists the message; search
   by sender/subject finds it; open it, mark unread/read, archive.
8. Confirm the unread count and the Archived tab behave (archived is excluded
   from the badge).
9. Test an invalid Turnstile token, a filled honeypot and a rate-limited burst.
10. Stop the worker, submit, restart it → the queued delivery runs and the message
    was never lost.
11. Confirm profiles, organisations, training, tournaments and assessments behave
    exactly as before.

## 11. Exit criteria

| Criterion | Result |
|---|---|
| Production submissions require server-side Turnstile verification | ✅ (fail closed) |
| Rate limits return HTTP 429 safely | ✅ |
| Proxy IP handling correct for Render/Cloudflare | ✅ trusted-proxy list includes Cloudflare |
| Honeypot and malformed requests handled safely | ✅ |
| No secret in frontend assets or logs | ✅ |
| Email/notification failures observable and non-destructive | ✅ |
| Only authorized platform staff can access message content | ✅ |
| Existing domain permissions unchanged | ✅ |
| Complete staging flow passes | ⏳ requires the operator steps above |
| Existing auth/notification/mail delivery continue to work | ✅ full suite |
