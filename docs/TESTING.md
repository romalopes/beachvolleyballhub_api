# Testing

The API repository owns its Rails tests and remains independent from the
Beach Volleyball Hub frontend repository. Browser-level Playwright tests belong
to the frontend repository; these tests verify Rails behavior, API contracts,
authorization, and the server-rendered public shell.

## Local commands

```bash
bin/rails db:test:prepare test
bin/rails test test/integration/api_smoke_test.rb
bin/rails test:system
bin/rubocop
```

The test environment must never use the development database. `.env.test`
selects `beachvolleyballproject_test`; CI additionally supplies a PostgreSQL
connection through `DATABASE_URL`.

## Test conventions

- Integration and controller tests use fixtures already maintained in
  `test/fixtures`.
- `SessionTestHelper` covers signed cookie sessions.
- `ApiTestHelper` covers JSON headers, bearer-token sessions, JSON parsing, and
  common API assertions.
- API tests must use test fixtures or records created during the test. They must
  not call production services or depend on production credentials.
- Authentication and authorization should be asserted explicitly, including
  unauthenticated and forbidden responses.
- Tests should assert observable contracts rather than implementation details.

## System tests

Rails system tests use Capybara and Selenium with headless Chrome. They are
intentionally small and cover the Rails-rendered shell. The frontend's
cross-browser Playwright suite is maintained separately and must not be
imported into this repository.

When running locally, install Chromium/Chrome and ensure Selenium can discover
it. CI installs Chromium before running `test:system`.

## CI artifacts

Failed system tests upload `tmp/screenshots`. The Rails test database is created
from the schema in the isolated test environment; no development or production
database is used.