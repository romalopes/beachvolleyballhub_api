# Phase 3 — Public React Contact page

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §4.1, §5.1, §6.1
**Status:** Complete.

## 1. Delivered files (`beachvolleyballhub` frontend)

| File | Purpose |
|---|---|
| `src/pages/Contact.tsx` | The public form, success/error/retry states, privacy note |
| `src/pages/Contact.test.tsx` | 13 examples |
| `src/services/turnstile.ts` | Script loader, site key, action constant (no secret) |
| `src/components/TurnstileWidget.tsx` | Explicit-render widget; reports the token only |
| `src/constants/contactTypes.ts` | Category labels + status labels (fallback list) |
| `src/api.ts` | Contact types + `submitContactMessage`, `contactMessageOptions` |
| `src/App.tsx` | Public `/contact` route |
| `src/components/Sidebar.tsx` | Top-level Contact link |
| `src/vite-env.d.ts` | `VITE_TURNSTILE_SITE_KEY` typing |
| `src/App.css` | Contact form styles (`.contact-*`, `.field-error`, `.visually-hidden`) |
| `.env.example` | Documents the site key |

## 2. Navigation placement decision

The plan asked for Contact "immediately before About if About exists". **There is
no About page in this application**, so the plan's fallback rule applies: place
Contact by the established product information architecture.

Decision: Contact is a **top-level public link** in the sidebar, next to the other
public destinations (Home, Tournaments, Training Sessions), rendered above the
grouped sections. It is visible to signed-out visitors and to every role. No new
group was invented for a single link, and no "About" neighbour was fabricated.
The choice is recorded in a comment above `contactLink` in `Sidebar.tsx`.

## 3. Form behaviour

| Aspect | Implementation |
|---|---|
| Fields | Name, Email, category, Subject, Message + hidden honeypot |
| Email when signed in | The account's address is shown **read-only** (no input to retype) and is sent as the message's `email`; signed out, the editable field is used. While the session is still resolving, a neutral "Checking your account…" placeholder is shown and submit is disabled |
| Limits | 120 / 254 / 180 / 10 000 characters, mirrored from the API |
| Client validation | Required fields + e-mail shape; **server remains authoritative** |
| Categories | Fetched from `GET /contact_messages/options`; bundled list is the fallback if that call fails |
| Duplicate submits | `submitting` guard + disabled button ("Sending…") |
| Success | Shown only after the API confirms; form resets and the widget is reset |
| Server errors | `ApiValidationError.errors` are mapped back onto fields by their Rails attribute prefix, unmatched messages shown as a general error |
| Rate limit | 429 renders "You have sent several messages recently…" |
| Turnstile | Token sent only when the widget is enabled; a failed submit resets the widget (tokens are single-use) |
| Accessibility | Every input has a label, `aria-invalid`/`aria-describedby` on errors, keyboard-only flow, honeypot `aria-hidden` + `tabIndex={-1}` |
| Privacy | Note states the information is used only to answer the enquiry and asks visitors **not** to send passwords, payment details, medical information, private details about minors, or player/coach/organisation records |

## 4. Turnstile wiring

- `VITE_TURNSTILE_SITE_KEY` is the only key in the bundle. The secret never
  appears in any `VITE_*` variable or browser code.
- The script is loaded once per page (`render=explicit`), the widget is rendered
  with `action: "contact"`, and the component reports `null` on error/expiry/
  timeout so the form cannot pretend to be verified.
- When the key is absent (local development), the widget is not rendered and the
  API decides (test/development: disabled; production: fail closed).
- The client never treats a token — or the widget's success callback — as
  verification.

## 5. Tests

```bash
npx vitest run src/pages/Contact.test.tsx
```

Covered: renders without a session, server categories replace the fallback,
fallback survives an options failure, required-field and e-mail validation blocks
the request, a valid submission calls the API with the exact payload, a second
click while pending is ignored, server validation errors map to fields and keep
the entered values, a 429 shows actionable copy, the privacy note is present, and
the honeypot stays out of the accessibility tree.

Signed-in behaviour is pinned by three further examples: the account address is
displayed instead of an editable field, a submission carries the account address,
and the session-unresolved state shows the placeholder with submit disabled.

## 6. Exit criteria

| Criterion | Result |
|---|---|
| Navigation placement documented (no About page) | ✅ §2 |
| Page accessible without login | ✅ |
| Signed-in visitors do not retype an email we already hold | ✅ read-only display, address sent with the message |
| Works on mobile and desktop | ✅ responsive card + wrapping controls |
| Client validation improves usability; server authoritative | ✅ |
| Turnstile token sent, never treated as verified client-side | ✅ |
| Duplicate submission prevented while pending | ✅ |
| Success only after confirmed API success | ✅ |
| Errors understandable and free of internal detail | ✅ |
| No secret in the frontend build | ✅ only the public site key |
| Privacy note discourages sensitive information | ✅ |
