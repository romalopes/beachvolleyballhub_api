# Pundit Authorization Architecture and Migration Status

Last updated: November 1, 2026.

## Actor semantics

- `ApplicationController#pundit_user` returns `Current.user`, the effective
  user. During impersonation, ordinary content and ownership authorization acts
  as the impersonated user.
- Policies that protect site administration use `real_user` / `real_admin?`
  from `ApplicationPolicy`, which read `Current.real_user`. An impersonating
  administrator therefore retains only the explicitly designated real-admin
  capabilities.
- Policies deny by default. A protected controller action should use
  `authorize`; collection reads should start from `policy_scope`.

## Denial response contract

`ApplicationController#handle_pundit_unauthorized` is the shared boundary:

- denied `show?` queries return `404 Not Found`, including for an authenticated
  caller, so a hidden record cannot be distinguished from a missing record;
- other unauthenticated denials return `401 Unauthorized`;
- other authenticated denials return `403 Forbidden`;
- HTML requests use the existing redirect/not-found behavior.

Controllers should not reproduce this response logic with inline role checks.

## Lifecycle and catalogue rules

- Public catalogue policies for drills, skills, and videos expose only records
  that are both `published` and `shared`.
- Hidden lifecycle states (`draft`, `archived`, private, and unlisted where
  supported) are excluded by policy scopes and protected record queries.
- Analysis lifecycle actions use explicit Pundit queries (`publish?`,
  `archive?`, `destroy?`, and assessment-session link/unlink queries).
- Analysis comments are deletable only by their author or an administrator.
- Player-profile visibility is a soft catalogue preference. Direct hidden
  record access is still denied with `404`; scheduling may intentionally request
  the wider manager scope with `include_private=1`.

## Completed migration slices

- Application-wide Pundit integration and denial handling.
- Admin-area wrapper policy.
- Categories, drills, skills, videos, video categories/tags, training sessions,
  training templates/series, and analyses.
- Analysis child resources (videos, annotations, and comments).
- `PlayersController`, including Pundit-native `PlayerProfilePolicy` and scope.
- `ProfilePolicy` now lives under `app/policies` and supports normal Pundit
  construction. Temporary keyword-constructor and `.scope` compatibility remain
  for untouched model/service/controller callers.

## Remaining migration inventory

As of November 1, 2026, repository search still finds:

- 18 `render_unauthorized_or_forbidden` references, including the central
  handler itself and legacy controller concerns;
- 33 compatibility-style `ProfilePolicy.new(actor: ...)` / `.scope(...)`
  references, concentrated in `CoachesController`, claim/invitation flows,
  profile models, and profile services;
- direct role checks in accounts, assessment resources, organisations/groups,
  locations, claims, and several legacy concerns.

Next slices should migrate `CoachesController`, then claim/invitation/profile
services, followed by assessment and organisation/group authorization. Remove
the compatibility constructor and `.scope` only after those callers are gone.

## Testing expectations

For each migrated resource, cover at least guest, owner/creator, unrelated user,
coach or manager, curator, and administrator behavior where those roles apply.
Record-read tests must include direct ID access to a hidden record and assert
`404`, not only exclusion from an index.

## Migration timestamp note

`db/migrate/20261031000002_add_visibility_status_to_skills_and_videos.rb` is
dated October 31, 2026. On November 1, 2026 it is not future-dated. Before
release, still verify that its timestamp orders correctly after every migration
already deployed to each environment; rename it only if a deployed environment
already has a later migration that would make ordering unsafe.