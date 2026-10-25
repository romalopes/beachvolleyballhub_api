# Phase 7 — Organisation and Group Frontend

**Completed:** 25 October 2026

## Delivered

- Organisation detail page gained a **Locations** section listing the venues
  attached to the organisation, with the current default marked.
- Editors may attach a verified venue, set a venue as the organisation's
  default, and detach a venue. Attach and detach are distinct actions because
  the server requires a default to be one of the organisation's own attached
  locations.
- The attach picker searches the verified, active catalogue server-side
  instead of listing every venue in a dropdown.
- The Tournament form pre-fills from the selected organisation's
  `default_location`; the Training form pre-fills from the selected group's
  `effective_default_location`.
- A prefill never overwrites what the organiser entered: a field is filled only
  while it is empty or still holds a value an earlier prefill wrote, and a field
  the organiser has edited is never touched again.
- A default venue outside the first page of the catalogue is added to the local
  venue list so the selector can render it, and its courts are loaded with it.

## Authorization

- The panel's write controls render only when the organisation's server-stamped
  `can_edit` flag allows it, mirroring the backend's
  `OrganisationAccess.can_edit?` check. The server remains the authority.

## Deferred UI scope

- Group override/inheritance selector with an explicit "uses the organisation
  default" state on the Group detail page.
- Organisation/Group map or directions display.
- Proposal flow launched from those pages.
