# Phase 8 — Cancellation Notifications, Audit & Observability

**Status:** ✅ Complete
**Date:** 2026-10-21

## Migration

`20261021000005_add_cancellation_notified_at_to_training_session_participants.rb`
adds `cancellation_notified_at` (datetime). It is the per-participant
idempotency guard for cancellation email.

## Delivery path

1. `TrainingSeriesCanceller` cancels rows in a transaction, then (when
   `notify_participants: true`) calls
   `TrainingSessionCancellationNotifier`.
2. The notifier loads participants with `player_profile → account → user` and
   enqueues `TrainingSessionCancellationJob` for each reachable email, skipping
   rows already stamped.
3. The job reloads the participant, verifies the session is still cancelled,
   locks the participant row, re-checks the timestamp, sends
   `TrainingSessionsMailer.cancelled` with `deliver_now`, and stamps
   `cancellation_notified_at`.

Properties:

- **Idempotent** on job retry and on duplicate enqueue (row lock + re-check).
- **Best effort**: participants without an Account/email are skipped; the
  cancellation is still visible in the schedule.
- **No cross-request coupling**: the job receives only an id.
- Failures are logged and re-raised so the job's `retry_on` policy applies.
- Enqueue failures are logged and do **not** fail a committed cancellation.

Mailer views use the series IANA zone (`session.training_series.time_zone`) and
include title, local date/time, location and reason.

## Audit

`LogService` rows are written for:

- template create/update/archive/restore/clone;
- series create, bulk cancel, bulk delete, stop, cancel future, update future,
  split.

Descriptions name the action and count; LogService never raises, so logging
cannot break the request.

## Test evidence

```text
bin/rails test test/jobs/training_session_cancellation_job_test.rb
6 tests, 23 assertions, 0 failures
```

Covered: email delivery + timestamp, retry idempotency, accountless participant
skipped, non-cancelled session skipped, unknown participant ignored, notifier
enqueues only reachable participants. Service tests also assert the default is
"no notification" and that opting in enqueues exactly one job per reachable
participant.

## Observability notes

- No new metrics/dashboards were added. Failures surface through the existing
  job error logging (`[recurring-training] cancellation email failed …`) and
  Sentry (job exceptions).
- Email delivery honours the existing test-mode redirect in
  `ApplicationMailer`.

## Limitations

- No in-app notification record; email is the only outbound channel.
- A participant added *after* cancellation is impossible (the participant model
  refuses new rows on cancelled sessions), so there is no "notify late joiners"
  case.
- Cancelling many occurrences enqueues one job per participant per occurrence;
  the queue adapter handles the fan-out.
