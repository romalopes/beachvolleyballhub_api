# Phase 8 — Email and durable delivery

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §10
**Status:** **Deferred (feature-disabled by design)** — schema and interface prepared, delivery not enabled.

## 1. Why not enabled

The plan attaches an explicit **deployment gate** to this phase:

> "if no reliable worker is available on the current Render plan, keep email phase disabled rather
> than silently losing jobs."
> "Do not assume Render free tier provides a reliable always-on worker."

The audit (Phase 0) confirmed the relevant facts but **not** the operational one:

| Fact | Status |
|---|---|
| Solid Queue is installed | ✅ `Gemfile`, `config/environments/production.rb:79` (`config.active_job.queue_adapter = :solid_queue`) |
| Brevo HTTP adapter exists | ✅ `lib/brevo_delivery.rb`, `lib/mail_transport.rb` |
| A Render **worker service** is documented as required | ✅ `docs/LOCAL_VERCEL_RENDER_SETUP.md` §4 states the worker must run for queued mail |
| A worker is **actually running in production** | ❓ **not verifiable from this repository** |

Because that last fact cannot be verified from source, enabling notification email would risk the
exact failure the plan forbids: rows marked "sent" that were never delivered, or silently dropped
jobs. **Email delivery therefore remains off**, and no `deliver_later` call was added for
notifications.

## 2. What was prepared (so the phase is additive later)

The `notifications` table already carries the outbox columns this phase needs:

| Column | Purpose |
|---|---|
| `emailed_at` | Set when a delivery succeeds |
| `email_failed_at` | Set on terminal failure |
| `email_error` | Last provider error |

`NotificationPreference` already carries `email_enabled` and `email_cadence`, and the API already
exposes them, so the UI and data model need **no** further migration when delivery is enabled.

`Notifications::Publisher` already returns `created:` per result, which is exactly the set a
delivery job should enqueue — so a future `Notifications::EmailDeliveryJob` can be added without
touching the publisher's contract.

## 3. Required steps to enable (checklist for the operator)

1. Confirm a continuously running Solid Queue worker on Render (`bin/jobs` / the documented worker
   start command) and that it shares the production queue database.
2. Verify Brevo credentials (`BREVO_API_KEY`), verified sender domain and quota headroom.
3. Add a mailer + templates for the high-value events only: `training.cancelled`,
   `training.rescheduled`, `training.invited`, `membership.approved`, `membership.rejected`.
4. Add a `Notifications::EmailDeliveryJob` that:
   - is enqueued only for `created: true` results;
   - re-checks `email_enabled` and `email_cadence` at send time;
   - is idempotent (skip when `emailed_at` is already set);
   - records `emailed_at` / `email_failed_at` / `email_error`;
   - performs **no external HTTP inside a DB transaction**;
   - uses bounded retries with backoff.
5. Never put private assessment/analysis detail in a subject or preheader.
6. Honour `email_cadence` (`daily`/`weekly` via a digest job; `none` = never).

## 4. Explicitly not done

- ❌ No `deliver_later` for notifications.
- ❌ No digest job.
- ❌ No provider error-handling code (nothing calls it yet).
- ❌ No change to `MailTransport` / `BrevoDelivery` (they already work for existing mail).

This keeps the in-app system fully functional and honest: nothing claims to be emailed when it is not.

## 5. Exit criteria

| Criterion | Result |
|---|---|
| Existing Brevo adapter reused, not replaced | ✅ untouched |
| Notification creation succeeds regardless of email | ✅ (no email path exists) |
| No jobs silently lost | ✅ (none enqueued) |
| Retries / status tracking | ⏳ blocked on worker verification |
| Idempotent delivery | ⏳ prepared (`emailed_at` + `created:` flag) |
