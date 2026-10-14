## 10. Phase 8 — Admin forms and organisation integration

Provide admin-only create/edit forms for name, organiser, scope, scheme, divisions, dates, timezone, all-day, location, description, website and lifecycle actions. Admin can add/deactivate divisions and reorder/add/remove watch links. Prevent final active division removal and scheme changes after participation. Search/select only eligible existing organisations; preserve their hierarchy and access controls. Display organiser-linked tournaments on organisation details **only where existing organisation access rules permit**; do not expose private rosters.

**AI prompt — administration**

Build tournament admin CRUD and division/watch-link management using the application's existing admin UI, role guards, forms and Organisation selector. Respect backend permissions; client guards are not security controls. Support atomic nested creation, timezone/DST validation, edit conflicts, confirmation for cancel/archive/delete, safe URL links, and explicit errors when a referenced division cannot be removed. Extend Organisation details and deletion-blocker UI only as authorized by existing code. Add React tests and Rails request coverage for critical flows.

**Gate:** frontend build and integration tests pass; admin flows work and respect backend permissions.