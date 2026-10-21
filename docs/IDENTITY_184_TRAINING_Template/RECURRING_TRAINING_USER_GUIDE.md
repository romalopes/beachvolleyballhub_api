# Recurring Training — Coach Guide

This guide covers reusable training templates, weekly series, and the series
dashboard. Everything is available to coaches, curators and admins
(`Training → Templates` / `Training → Series`).

## Finding trainings

**Training** is now a single directory with a **List / Calendar** toggle:

- **List** shows each session as a card (date, time, location, status, series
  tag), grouped into calendar weeks. Each week gets its own heading, e.g.
  "Week from Sep 7 to Sep 13", so a long schedule reads week by week. Weeks
  without sessions are not shown.
- **Calendar** shows the schedule in a month or week grid with previous / Today
  / next navigation.
- The **Filters** panel narrows the schedule by status and by "only sessions I
  participate in". Opening the page from a series dashboard adds a
  `training_series_id` filter with a clear link.
- The chosen view, period and filters are part of the URL, so a link can point
  at any of them. `/calendar` still works: it redirects to
  `/training?view=calendar`.

## 1. Create a template

1. Go to **Training → Templates → New template**.
2. Enter a name and optional description.
3. Pick an organisation, group and coach if they apply. The group list is
   filtered to the selected organisation; a group with no organisation is always
   available. The API refuses a group that belongs to a different organisation.
4. Add the usual location, location detail, level, capacity, duration and
   visibility.
5. Save.

Templates are **archived**, never deleted. Archiving hides a template from the
default list and refuses new series, but existing series keep working. **Clone**
makes an active copy named `"<name> (copy)"`.

## 2. Schedule a series

1. **Training → Series → New series** (or **Schedule** on a template row).
2. Choose the template. Its duration/location defaults are prefilled; a blank
   title means occurrences use the template name.
3. Set the start and end dates, weekdays, local start time, duration, repeat
   interval (1–4 weeks) and time zone.
4. Optionally override title, level, location, location detail and capacity.
   Overrides are stored per series; the template is not changed.
5. Click **Preview dates**. The preview shows the total, the first ten dates in
   the series time zone, daylight-saving warnings and advisory conflicts
   (same coach or same location string).
6. Click **Create series**. Occurrences are created as `scheduled` sessions and
   the dashboard opens.

Rules: end date is inclusive; a window may not exceed 366 days or 200
occurrences; a non-existent local time (spring-forward gap) is rejected. An
ambiguous local time (fall-back overlap) uses the earlier instant and shows a
warning.

## 3. Use the series dashboard

The dashboard lists every occurrence with date, time, status, coach, location
and flags (Edited / Cancelled / Locked). Use the checkboxes to select
occurrences, then open a section under **Series actions**:

| Action | What it does |
|---|---|
| **Cancel selected occurrences** | Marks the selected occurrences `cancelled` with a reason, keeps them visible as tombstones, and optionally emails participants with an account. |
| **Delete selected drafts** | Deletes only drafts that have no participants and no assessments. Anything with history is kept. |
| **Stop recurrence** | Stops generating new occurrences. Existing occurrences are untouched. |
| **Cancel future occurrences** | Cancels every still-cancellable occurrence from a local date onward. |
| **Edit future occurrences** | Changes selected fields on future scheduled occurrences. Occurrences that were already edited keep their values unless you tick "Overwrite existing overrides". |
| **Split series at a new rule** | Ends the old series the day before the boundary and creates a new series with the new pattern. Blocked if future occurrences already have participants, assessments or (unless allowed) overrides. |

**Important distinctions**

- *Stop* does not cancel anything; *cancel* does not delete anything.
- A cancelled occurrence cannot come back when the series is regenerated.
- Deleting is intentionally narrow; use cancel for anything with people
  attached.
- Emails are best effort and sent once per participant.

## 4. One-off sessions

**Training → New Training** is unchanged. Series occurrences are ordinary
training sessions: open one to edit its roster, focuses, drills or videos
without affecting its siblings.

## 5. Troubleshooting

| Message | Meaning |
|---|---|
| "Training template is required" | Choose a template before previewing/creating. |
| "Archived templates cannot be scheduled" | Restore or clone the template first. |
| "Weekdays must include at least one weekday" | Select at least one day. |
| "…does not exist in … (daylight-saving transition)" | Choose a different local time for that date. |
| "This recurrence would generate N sessions; the maximum is 200" | Shorten the range or use a longer interval. |
| "Some future occurrences have participants, assessments or overrides" | Cancel/withdraw those occurrences first, or allow discarding overrides when splitting. |
| New pages show "Recurring training is not available" | The API feature flag is off; ask an administrator. |

## Known limitations

- Location is free text; there is no court booking or court-level conflict
  detection yet.
- Capacity is shown but not enforced when adding participants.
- Splitting cannot destroy registrations; this is deliberate.
