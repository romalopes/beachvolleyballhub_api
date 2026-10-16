# Tournament Calendar V2 — Admin Guide

Who: real admins (not impersonating) and users with `OrganisationAccess.edits_record_by_membership?` for the tournament's organisation. Enforced by `TournamentManagementAuthorization`; unauthorised writes return 403.

## Create a tournament (`/admin/tournaments` → Create Tournament)

1. Fill name, organisation, scope, division scheme, start/end date-time (or all-day), timezone.
2. The tournament is created as **draft** — invisible to the public until published.

## Manage divisions (edit form)

- Add a division (letter level and/or number).
- Reorder, edit or remove. Note: a division referenced by a participation cannot be removed (it is retired); the last active division cannot be retired.
- The division scheme locks once anyone has participated.

## Manage watch links (edit form)

- Add streaming/coverage URLs, reorder (they display in order on the detail page), or remove.

## Lifecycle

| Action | When |
| --- | --- |
| **Publish** | content final → visible in the public directory (`active`) |
| **Cancel** | event called off → `cancelled`, shown struck-through in the calendar |
| **Archive** | tidy the list once a past event needs no management |
| **Restore** | bring a cancelled/archived tournament back to `active` |
| **Delete** | only while unused (no participations) |

Every destructive/lifecycle action asks for confirmation in the UI.

## Visibility

`draft` tournaments appear to you and your organisation's managers only. The public directory and calendar show `active` (and cancelled events marked "Cancelled") regardless of organisation.
