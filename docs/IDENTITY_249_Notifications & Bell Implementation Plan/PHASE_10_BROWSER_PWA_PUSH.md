# Phase 10 — Browser / PWA push

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §12
**Status:** **Deferred (optional)** — not implemented in this change.

## 1. Why deferred

The plan marks this phase **optional** and lists prerequisites that do not exist yet:

> "Ask for permission only after an explicit user action in settings; do not prompt at initial page load."
> "Use native browser Push API … plus Ruby `web-push` with VAPID."

Audit findings:

| Prerequisite | Status in BVH |
|---|---|
| Service worker | ⚠️ `app/views/pwa/service-worker.js` exists but is a **comment-only placeholder** ("Add a service worker for processing Web Push notifications"), not an implementation |
| `web-push` gem | ❌ not in `Gemfile` |
| VAPID keys | ❌ none configured |
| Push subscription storage | ❌ no table |
| Durable delivery path | ❌ blocked on Phase 8 (worker verification) |
| Explicit-consent UI | ❌ not built |

Shipping push without these would either do nothing or, worse, prompt users for a permission the app
cannot honour.

## 2. Dependencies

Push **depends on Phase 8**: the plan says to "deliver through the existing durable outbox". Since
the durable delivery path is itself gated on verifying a production worker, push cannot be reliably
delivered before that gate is passed. Attempting push first would invert the dependency order the
plan specifies.

## 3. What would be required to complete this phase

1. Verify the PWA/service-worker setup and whether the app is installable on the target browsers.
2. `bundle add web-push`; generate and store VAPID keys as secrets (never in the browser bundle).
3. Add a `push_subscriptions` table (multiple devices per account; encrypted/safe storage) with
   cleanup on logout and on `410 Gone` from the push service.
4. Add authenticated subscribe/unsubscribe endpoints.
5. Implement a real `service-worker.js` push handler with deep links to **safe internal routes only**.
6. Add an explicit, settings-only permission request (never on first load).
7. Minimise payload content — never include private assessment/analysis detail.
8. Test expired endpoints, unsupported browsers, multiple devices, logout and iOS caveats.
9. Never promise background reliability across all browsers (the plan's own caveat).

## 4. Exit criteria

| Criterion | Result |
|---|---|
| In-app source of truth unchanged | ✅ (push not added) |
| PWA/service-worker setup verified first | ⚠️ verified as a placeholder only |
| VAPID + subscription storage | ⏳ not started |
| Explicit-consent permission UI | ⏳ not started |
| Delivered via durable outbox | ⏳ blocked on Phase 8 |
