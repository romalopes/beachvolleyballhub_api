# Phase 1 - Persistence and Model

## Status

Complete and verified on November 2, 2026.

## Scope

Phase 1 adds persistence and model support for one configurable Weather Advisor weight distribution per account. It does not yet change weather scoring, expose API endpoints, or personalize cached weather responses.

## Canonical repository

The backend implementation lives in:

`/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api`

Duplicate draft files created under `/Users/romalopes/Documents/studies/my_project/beachvolleyballhub_api` were removed during stabilization.

## Implementation

### Database

Migration: `db/migrate/20261102000001_create_weather_advisor_preferences.rb`

The `weather_advisor_preferences` table contains:

| Column | Type | Default | Constraint |
|---|---|---:|---|
| `account_id` | bigint | - | not null, foreign key, unique index |
| `wind_weight` | integer | 40 | not null, 0 through 100 |
| `temperature_weight` | integer | 20 | not null, 0 through 100 |
| `rain_weight` | integer | 25 | not null, 0 through 100 |
| `uv_weight` | integer | 5 | not null, 0 through 100 |
| `humidity_weight` | integer | 10 | not null, 0 through 100 |

An additional database check requires all five weights to total exactly 100. Rails `add_check_constraint` helpers are used instead of adapter-specific raw `ALTER TABLE` statements, making the migration reversible through normal Rails migration commands.

No rows are backfilled. An account without a preference row continues to mean “use the defaults.”

### Model

Model: `app/models/weather_advisor_preference.rb`

The model provides:

- `DEFAULT_WEIGHTS`, a frozen source of truth for `40/20/25/5/10`;
- `.defaults`, returning the default distribution;
- `#weights`, returning the persisted distribution with factor keys;
- integer and inclusive 0–100 numericality validation for every weight;
- account uniqueness validation;
- a nil-safe exact-total validation.

The nil guard prevents the custom total validator from raising when an individual attribute is absent; the attribute's numericality validation reports that error normally.

### Account ownership

`app/models/account.rb` now declares:

```ruby
has_one :weather_advisor_preference, dependent: :destroy
```

This follows the existing one-to-one preference convention and removes the preference when its owning account is deleted.

## Test coverage

`test/models/weather_advisor_preference_test.rb` uses the project's fixture-based Minitest conventions. It covers:

- database defaults and the public weights hash;
- valid custom distributions and 0/100 boundaries;
- negative, above-100, decimal, missing, and invalid-total values;
- one preference per account at both model and database layers;
- PostgreSQL range and total check constraints;
- dependent deletion with the owning account.

Database exception assertions are separate tests because PostgreSQL aborts the current transaction after a constraint violation.

## Verification

### Passed

```text
bin/rails db:migrate:down VERSION=20261102000001
bin/rails db:migrate:up VERSION=20261102000001
```

The migration completed successfully in both directions.

```text
bin/rails test test/models/weather_advisor_preference_test.rb test/models/account_test.rb
19 runs, 59 assertions, 0 failures, 0 errors, 0 skips
```

```text
bin/rubocop app/models/account.rb app/models/weather_advisor_preference.rb \
  db/migrate/20261102000001_create_weather_advisor_preferences.rb \
  test/models/weather_advisor_preference_test.rb
4 files inspected, no offenses detected
```

Ruby syntax checks and `git diff --check` also passed. `db/schema.rb` records schema version `2026_11_02_000001`, the unique account index, foreign key, and all six check constraints.

### Full-suite baseline

```text
bin/rails test
1676 runs, 6630 assertions, 18 failures, 4 errors, 1 skip
```

The reported failures are outside this phase and do not reference `WeatherAdvisorPreference`. They occur in existing organisation/group membership, weather fixture expectation, account invitation, tournament service, and health/email configuration tests. Phase 1's focused model/account suite remains green.

## Remaining work

- Phase 2 must parameterize `Weather::VolleyballAdvisor` while preserving default behavior.
- Later weather integration must not cache account-specific advisor output in the current shared location payload.
- Authenticated preference endpoints and frontend configuration remain out of scope for this phase.