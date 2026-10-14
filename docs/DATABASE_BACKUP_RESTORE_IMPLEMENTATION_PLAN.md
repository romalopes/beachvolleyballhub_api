# Database Backup, Restore and Cross-Provider Migration Plan

**Projects:** Wine Words (`wine_words_api`) and BeachVolleyballProject (`beachvolleyballproject_api`)  
**Targets:** local PostgreSQL, Neon, Supabase  
**Object storage:** Cloudflare R2 (already configured; objects are not part of PostgreSQL dumps)  
**Status:** Implementation specification; validate against each repository before coding.

## 1. Goals and non-goals

Provide one consistent, manually invoked CLI in each Rails API project to inspect database targets, create and verify backups, restore an archive, and safely copy application data between any two configured PostgreSQL databases: local ↔ Neon, local ↔ Supabase, Neon ↔ Supabase, and same-provider environments. Make it possible to recover production deliberately, but make destructive mistakes difficult. Produce operator documentation as part of implementation.

**Not in scope:** automated scheduled backups, continuous replication, bidirectional row-level synchronization, merging divergent records, backing up R2 object bytes, or cloning provider-managed Supabase services. `copy`/`refresh` means *replace destination application schema/data*, not merge/upsert.

## 2. Design decisions

1. Use PostgreSQL CLI tools (`pg_dump`, `pg_restore`, `psql`, `pg_isready` where appropriate), not Rails serialization or a provider-specific export API.
2. Prefer custom-format archives (`pg_dump -Fc`), SHA-256 checksums, manifests, and `pg_restore --list` verification. A readable archive is **not** proof of successful recovery: periodic test restores are required.
3. Restrict normal application backups to explicitly configured **application-owned schemas**, initially `public` only after auditing actual schemas. Do not restore Supabase-managed `auth`, `storage`, `realtime`, `vault`, etc.
4. Do not copy PostgreSQL cluster roles, ownership or grants by default (`--no-owner --no-acl`); create target roles/extensions separately as needed.
5. Default to **logical backup to disk followed by restore** for all copies, rather than a fragile direct database pipe. Retain the source dump and a preflight snapshot of destination until success is verified.
6. Treat target names as **project-scoped aliases**, not provider names. Example: `local`, `neon_dev`, `neon_prod`, `supabase_dev`, `supabase_prod`; `production` is a protected designation independent of provider.
7. Never infer production safety solely from alias text. Store an explicit `protected: true` property and fingerprint the target host/database; fail closed when configuration is ambiguous.
8. R2 files remain untouched. Backups preserve Active Storage attachment/blob/variant metadata and object keys, but only work with the corresponding objects still available in R2. No R2 deletion, copying or re-keying by default.
9. No credentials in arguments, logs, manifests, commits, error messages, or shell history. Use env vars and `PGPASSFILE`/secure password handling; avoid `set -x`.
10. Use a small shell or Ruby CLI wrapper with tested argument parsing, rather than duplicating implementation across Rails tasks. Extract a shared internal script/library or keep synchronized copies with explicit versioning.

## 3. Important compatibility and safety constraints

- Verify installed PostgreSQL client tools and server versions. `pg_dump` must not be older than the source server major version; test restore compatibility with destination version. Prefer destination major version >= source major version for migrations, but still test extensions/SQL compatibility.
- Supabase and Neon may expose **pooler URLs** and **direct connection URLs**. Use a supported direct/non-transaction-pooling connection for administrative dump/restore operations, with SSL configured (`sslmode=require` or stronger as appropriate). If direct connectivity is unavailable, validate the provider's supported alternative; do not silently fall back to transaction poolers.
- A `public`-only dump may omit required extensions, custom types, cross-schema dependencies, functions, or roles. Preflight must inspect dependencies and document provisioning steps. Never drop provider-managed schemas.
- `pg_restore --clean --if-exists` can remove existing application objects, but it is **not** a universal safe full-database replacement. Prefer restoring into an empty, disposable destination database/branch or a controlled app schema after checking all dependencies and active connections. If target is shared with other apps, refuse destructive restore.
- `--single-transaction` can make a supported restore atomic but does not replace preflight checks, and may fail for certain operations. Use it when supported and surface errors without retrying destructively.
- Source and target must be distinct physical databases for `copy`; compare fingerprints and reject self-copy. Do not permit Wine Words → BVP (or reverse) without an explicit unsupported override decision; default **reject cross-project**.
- For a live production database, coordinate maintenance/read-only mode and prevent concurrent writes during restore. A backup captures a consistent PostgreSQL snapshot, but object changes in R2 are not transactionally synchronized with it.
- On production-to-local refresh, avoid exposing real user data: require opt-in and optionally sanitize personal data, tokens, email addresses and secrets in the local copy. Disable outgoing mail, webhooks and background jobs before local use.
- Post-restore, inspect Rails `schema_migrations` and `ar_internal_metadata`; do **not** automatically run migrations on production. Ensure schema compatibility with the checked-out application revision.
- Supabase Auth/Storage metadata and provider extensions are out of scope; if either application later depends on them, create a separate provider-aware migration plan.

## 4. Repository structure

Implement independently in both API repositories, ideally using the same internal tool version:

```text
bin/db_tool
lib/db_tool/cli.rb
lib/db_tool/config.rb
lib/db_tool/connection.rb
lib/db_tool/preflight.rb
lib/db_tool/backup.rb
lib/db_tool/restore.rb
lib/db_tool/copy.rb
lib/db_tool/verify.rb
lib/db_tool/manifest.rb
lib/tasks/db_tool.rake                # optional wrappers only
config/database_targets.example.yml
spec/db_tool/ or test/db_tool/
backups/.gitkeep
docs/DATABASE_BACKUP_RESTORE.md
```

Add `/backups/*`, `*.dump`, `*.dump.sha256`, private `.env` files and any temporary credentials to `.gitignore` while preserving `backups/.gitkeep`. Keep local dumps in a directory with restrictive permissions (0700); files 0600. Make the output directory configurable.

## 5. Target configuration

Use **environment variable names** in YAML, not literal passwords or URLs. Sample:

```yaml
project: wine_words # bvp in the other repo
schemas: [public]
backup_directory: backups
connections:
  local:
    url_env: DB_TOOL_LOCAL_URL
    protected: false
    provider: local
  neon_dev:
    url_env: DB_TOOL_NEON_DEV_URL
    protected: false
    provider: neon
  neon_prod:
    url_env: DB_TOOL_NEON_PROD_URL
    protected: true
    provider: neon
  supabase_dev:
    url_env: DB_TOOL_SUPABASE_DEV_URL
    protected: false
    provider: supabase
  supabase_prod:
    url_env: DB_TOOL_SUPABASE_PROD_URL
    protected: true
    provider: supabase
```

Provide `.env.example` with placeholders only. Existing Rails `DATABASE_URL` must not be modified by backup tooling. Make configuration extensible for additional environments. Ensure `db_tool status` masks URLs and never prints passwords.

## 6. CLI contract and examples

Use these as the *proposed interface*; tests and docs must match the final implementation exactly.

```bash
# List targets and show safe, redacted status
bin/db_tool targets
bin/db_tool status --target neon_dev
bin/db_tool preflight --source neon_prod --target supabase_dev

# Create archive, checksum and manifest
bin/db_tool backup --source local
bin/db_tool backup --source neon_prod --output backups/manual.dump
bin/db_tool backup --source supabase_prod

# Validate archive structure/checksum and show metadata
bin/db_tool list
bin/db_tool inspect --file backups/manual.dump
bin/db_tool verify --file backups/manual.dump

# Restore a file to a destination (destructive)
bin/db_tool restore --file backups/manual.dump --target local
bin/db_tool restore --file backups/manual.dump --target neon_dev

# Copy via a verified, retained intermediate archive (destructive to target)
bin/db_tool copy --source local --target neon_dev
bin/db_tool copy --source local --target supabase_dev
bin/db_tool copy --source neon_dev --target local
bin/db_tool copy --source supabase_dev --target local
bin/db_tool copy --source neon_dev --target supabase_dev
bin/db_tool copy --source supabase_dev --target neon_dev

# Same-provider examples
bin/db_tool copy --source neon_prod --target neon_dev
bin/db_tool copy --source supabase_prod --target supabase_dev

# Dry run: validate targets, show proposed operations, never mutate
bin/db_tool copy --source neon_prod --target local --dry-run
```

**Production safeguards:** any operation writing to a protected target must require interactive typed confirmation with project, target alias, and database fingerprint; require a fresh verified destination backup and an explicit `--allow-protected-target` flag. Do not implement `--yes` or a generic force bypass for protected targets. For non-interactive contexts, refuse production writes. Require typed confirmation for all destructive restores, even development, unless the destination is an explicitly disposable test database.

`restore` and `copy` should by default create and verify a pre-operation destination backup. On failed backup, abort before modifying destination. Avoid claiming rollback is automatic; provide documented recovery from the pre-operation archive.

## 7. Implementation phases with AI coding prompts

### Phase 0 — Audit both applications and environments

**Tasks**
- Inspect Rails versions, `config/database.yml`, migrations, schemas, extensions, Active Storage setup, R2 configuration, PostgreSQL versions, and existing backup tooling.
- Check whether app tables live only in `public`, whether the apps use Supabase Auth, and whether databases are dedicated to a single app.
- Identify current local, Neon, Supabase and production/staging connection patterns without exposing secrets.
- Record any blockers and revise assumptions before code changes.

**AI prompt**

> Inspect the Wine Words API and BVP API repositories independently. Inventory database configuration, Rails migrations, schema ownership, extensions, PostgreSQL versions, Active Storage tables and Cloudflare R2 usage. Identify which database schemas are application-owned and whether any Supabase-managed schemas are needed. Do not change code or reveal secrets. Write `docs/DATABASE_BACKUP_AUDIT.md` for each repository with verified findings, risks, and a proposed target configuration. Stop and ask for clarification if the database is shared or the schema boundaries are unclear.

**Acceptance:** audited environment matrix; no unverified schema assumptions.

### Phase 1 — Configuration and CLI skeleton

**Tasks**
- Implement target YAML loader, env-variable resolution, alias validation, project identifier and protected flag.
- Implement `help`, `targets`, `status` and structured exit codes.
- Add redaction and tests for malformed config, missing secrets, invalid aliases and ambiguous production settings.

**AI prompt**

> Implement `bin/db_tool` and modular Ruby services for the audited Rails API. Support `help`, `targets`, and `status` with YAML target aliases referencing environment variable names. Validate URLs, mask credentials, and explicitly classify protected destinations. Add unit tests, `.env.example`, config example and `.gitignore` rules. Do not make any database mutations. Ensure both repositories expose the same CLI syntax and record differences in a changelog.

**Acceptance:** safe commands run without printing secrets.

### Phase 2 — Preflight and compatibility engine

**Tasks**
- Confirm executable availability and versions (`pg_dump`, `pg_restore`, `psql`).
- Test connectivity with a minimal read-only query; collect redacted fingerprint (provider, host, database, server major version).
- Check direct connection/SSL, source and destination version compatibility, application schemas, extensions, permissions, free disk space and target readiness.
- Reject same database, cross-project and unsafe shared-schema operations.
- Support `--dry-run` with no writes.

**AI prompt**

> Add `preflight` for backup, restore and copy. Check client/server PostgreSQL versions, source and destination connectivity, SSL/direct connection requirements, extension/schema dependencies, project identity, destination ownership and same-database fingerprints. Reject incompatible or unsafe operations before running destructive SQL. Print a concise redacted execution plan. Unit-test all rejection paths and add integration tests with disposable local PostgreSQL instances.

**Acceptance:** known incompatibilities fail before restore.

### Phase 3 — Backup and manifest

**Tasks**
- Use `pg_dump -Fc` with configured application schemas and `--no-owner --no-acl` (verify option compatibility).
- Write to a temporary file, check process exit status, run `pg_restore --list`, calculate SHA-256, and atomically publish archive + manifest.
- Manifest fields: format version, project, source alias/provider, redacted source fingerprint, timestamp UTC, tool/server version, schemas, archive filename, size, SHA-256, application git SHA (if available), R2 storage reference note.
- Add `list`, `inspect`, `verify`; fail on missing/invalid checksums and mismatched project identifiers.

**AI prompt**

> Implement safe manual PostgreSQL backups using custom-format `pg_dump`, selected application-owned schemas, checksums and a JSON manifest. Use temporary files, restrictive permissions, atomic finalization and reliable subprocess exit handling. Add `list`, `inspect`, and `verify`. Do not include secrets in files or output. Explicitly state that `pg_restore --list` is only structural verification, not a full recovery test. Write tests for interrupted dumps, bad archives, checksum mismatches and disk failures.

**Acceptance:** repeatable backups from local, Neon and Supabase; corrupted archives rejected.

### Phase 4 — Restore engine and destination protection

**Tasks**
- Require archive validation and matching project/schema identity.
- Perform destination preflight, snapshot destination, typed confirmation, then controlled restore.
- Prefer disposable empty target database/branch where possible; otherwise restore only explicitly owned application objects and document deletion strategy. Do not run unrestricted `DROP SCHEMA public CASCADE` against a managed or shared database.
- Execute `pg_restore` with safe ownership/ACL handling; use `--single-transaction` where compatible. Capture redacted logs.
- On failure, stop and report precise manual recovery command using the destination pre-backup. Never falsely report automatic rollback.

**AI prompt**

> Implement `restore --file ... --target ...` with mandatory archive verification, project matching, database fingerprint display, protected-target checks, automatic verified pre-restore destination backup and exact typed confirmation. Restrict destructive actions to application-owned schemas/objects; refuse shared or provider-managed schemas. Use PostgreSQL restore flags compatible with the destination and surface errors clearly. Do not run migrations automatically. Add failure-injection and restoration tests using disposable databases.

**Acceptance:** restore works to disposable local target; wrong-project/protected/shared targets are blocked.

### Phase 5 — Cross-provider copy and refresh

**Tasks**
- Implement `copy` as source backup → verification → destination pre-backup → restore → post-checks.
- Support every local/Neon/Supabase combination, including same-provider different databases.
- Handle provider-specific extension/provisioning requirements via preflight hooks, not hard-coded destructive SQL.
- Keep source and destination backup archives until explicit cleanup; print locations and recovery instructions.
- Reject generic `update`/merge semantics; document replacement clearly.

**AI prompt**

> Implement `copy --source ALIAS --target ALIAS` by orchestrating the existing verified backup and guarded restore services. Support local ↔ Neon, local ↔ Supabase, Neon ↔ Supabase and same-provider environments. Preserve source and destination archives, reject source=destination and cross-project operations, and provide a dry-run. Do not implement row-by-row merging or silently migrate provider-managed schemas. Add integration tests for each direction using disposable PostgreSQL targets and document any provider tests requiring credentials.

**Acceptance:** all six directional cases tested or clearly marked as pending live-provider validation.

### Phase 6 — Rails and R2 integration checks

**Tasks**
- Confirm restored `schema_migrations` and `ar_internal_metadata` match the intended application revision.
- Validate representative Rails records and associations; verify Active Storage blob/attachment metadata and sample R2 object existence using read-only HEAD requests when explicitly enabled.
- Do not copy, overwrite, or delete R2 objects. Do not change Active Storage keys.
- Prevent unintended outgoing mail/jobs/webhooks in non-production restored copies; offer a separately approved data sanitization task.
- Include notes on R2 lifecycle/versioning and database/object consistency gaps.

**AI prompt**

> Add a post-restore validation command that checks Rails schema migration status, key application tables, foreign keys, row counts, and representative Active Storage associations. If R2 verification is configured, perform read-only existence checks for a small sample of referenced object keys without logging secrets or accessing object contents. Do not mutate R2. For production-to-local refreshes, warn about personal data and disable outbound integrations in documented local configuration. Add tests with fixtures.

**Acceptance:** database and storage-reference health report; no object mutations.

### Phase 7 — Operator documentation (mandatory deliverable)

Create `docs/DATABASE_BACKUP_RESTORE.md` **in both projects**, not just code comments. Include:

1. Purpose, architecture, supported direction matrix and explicit replacement-vs-merge warning.
2. macOS installation: Homebrew PostgreSQL client tools, PATH, checking versions; provider direct URLs and SSL.
3. Safe environment setup: example aliases, how to source env vars securely, and where to find Neon/Supabase direct connection strings without pasting credentials into commands.
4. Every CLI command: exact syntax, options, expected output, exit codes and what SQL/tool operations it performs.
5. Copy-paste walkthroughs for local→Neon, Neon→local, local→Supabase, Supabase→local, Neon→Supabase and Supabase→Neon, plus backup and restore within one provider.
6. Production restore runbook: maintenance window, destination snapshot, typed confirmation, post-restore smoke tests, rollback from pre-restore archive, resuming traffic.
7. `pg_dump`/`pg_restore` concepts, custom archive format, schema restrictions, checksums and limitations.
8. R2 explanation: database metadata versus object bytes, retention, missing-object checks and separate R2 backup strategy.
9. Rails migration policy, seed data cautions, email/job/webhook disabling and PII sanitization.
10. Troubleshooting: SSL, direct vs pooled URL, firewall/IP access, client/server version, extension errors, permissions, disk space, interrupted restore, missing tables, bad checksum, orphaned Active Storage references.
11. Security and retention: no commits of dumps, restrictive file permissions, encryption-at-rest options, controlled deletion and safe disposal of local production copies.
12. Example disaster recovery drill with clear success/failure criteria and measured RTO/RPO (do not invent values).

**AI prompt**

> Generate `docs/DATABASE_BACKUP_RESTORE.md` as a complete operator manual for this repository's *actual implemented* CLI. Include macOS prerequisites, safe credentials, all commands and flags, six source→destination walkthroughs, expected output, exact internal operations, protected-production procedure, rollback instructions, Rails migration checks, Cloudflare R2 limitations, troubleshooting and a recovery drill. Verify every documented command against CLI help and integration tests; remove any unsupported or hypothetical syntax. Do not expose real URLs or secrets.

**Acceptance:** a developer unfamiliar with the implementation can perform a safe local backup, test restore and dry-run using only this document.

### Phase 8 — Test matrix and release

| Test | Local | Neon | Supabase |
|---|---|---|---|
| Backup and verify | Required | Required | Required |
| Restore to empty/disposable destination | Required | Required | Required |
| Copy to local | — | Required | Required |
| Copy from local | — | Required | Required |
| Neon → Supabase | — | Source | Destination |
| Supabase → Neon | — | Destination | Source |
| Protected-target refusal | Required | Required | Required |
| Failure/recovery drill | Required | Recommended | Recommended |

Additional tests: malformed URL; password redaction; unavailable source; interrupted dump; bad checksum; incompatible major version; missing extension; cross-project archive; same source/target; shared-schema refusal; insufficient disk; failed pre-restore snapshot; failed restore; missing R2 object; pending Rails migrations; local email disabled.

**AI prompt**

> Execute the unit/integration suite and run the full directional matrix against explicitly designated disposable databases only. Never use a real production destination in automated tests. Produce `docs/DATABASE_BACKUP_TEST_REPORT.md` with commands, dates, server/client versions, passes/failures, provider limitations, recovery-drill outcome and unresolved risks. Confirm the operator manual matches the final CLI. Do not mark provider-specific tests passed unless actually executed.

**Acceptance:** all local tests pass; any untested remote scenarios are clearly disclosed before production use.

## 8. Suggested rollout sequence

1. Audit both repos and approve app-owned schemas and target aliases.
2. Build/test read-only commands and local backup first in Wine Words.
3. Implement local restore to a disposable database; prove recovery.
4. Validate Wine Words Neon/Supabase backups and copies with **development-only** databases.
5. Replicate shared implementation in BVP; adapt only configuration and app-specific health checks.
6. Complete docs and run recovery drills in both projects.
7. Only then enable protected-target restore behind explicit operator approval.

## 9. Operational checklists

### Before backup
- Confirm source alias and database fingerprint; verify sufficient free disk and secure destination directory.
- Confirm PostgreSQL tool compatibility and application schemas.
- Run backup; verify SHA-256 and archive listing; optionally test-restore to disposable database.

### Before restore/copy
- Verify source archive and project identity; check provider extensions and target version.
- Ensure target is dedicated, correct and writable; arrange maintenance if live.
- Create **verified** target snapshot; confirm path and checksum.
- Check R2 object continuity and environment-specific integrations.
- Type exact destructive confirmation; record operator and timestamp locally without secrets.

### After restore
- Check command exit status, table counts, integrity and application smoke tests.
- Check Rails migrations and Active Storage references; sample R2 HEAD verification.
- Confirm outbound mail/jobs/webhooks are safe for destination environment.
- Retain both source and destination snapshots according to retention policy.

## 10. Definition of done

- Same `bin/db_tool` interface in both API repos.
- Backups from local, Neon and Supabase, with archive and SHA-256 verification.
- Guarded restores and cross-provider replacement copies, with destination pre-backup.
- Explicit protection for production, provider-managed schemas, cross-project databases and R2 objects.
- Automated tests plus real-provider disposable-environment validation.
- `docs/DATABASE_BACKUP_RESTORE.md` and `docs/DATABASE_BACKUP_TEST_REPORT.md` in each repo.
- A documented, rehearsed disaster recovery process, not merely a successful `pg_dump`.

## 11. Master AI implementation prompt

> You are implementing a safe, manual PostgreSQL backup/restore/copy system for two separate Rails APIs: Wine Words and BeachVolleyballProject. The targets are local PostgreSQL, Neon and Supabase. Cloudflare R2 already stores application objects; do not back up, modify or delete those objects in this project. Follow `DATABASE_BACKUP_RESTORE_IMPLEMENTATION_PLAN.md` phase by phase. First inspect the actual repositories and create an audit; do not assume schemas, versions, connection aliases or extension availability. Use `pg_dump -Fc`, `pg_restore`, checksums, manifests, explicit app-owned schema boundaries, target pre-backups and strong protected-production confirmations. Support all six cross-provider directions as **destination replacement**, never implicit row-level merge. Build tests and operator documentation `docs/DATABASE_BACKUP_RESTORE.md` explaining exactly how to run every command and what it does. Stop for approval before destructive operations on non-disposable targets. Report what was implemented, tested, not tested, and any risks. Never reveal or commit credentials or dumps.
