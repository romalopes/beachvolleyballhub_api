#!/usr/bin/env bash
set -o errexit

# Render pre-deploy: migrate primary + cache + queue + cable.
# All four share the same DATABASE_URL in production (see config/database.yml),
# so all tables land in the same Postgres database.
# Missing `solid_cache_entries` here = 500 on every `rate_limit` endpoint
# (POST /api/v1/sessions, registrations, passwords, ...):
#   PG::UndefinedTable: relation "solid_cache_entries" does not exist
#
# Wired as `preDeployCommand` in render.yaml. Runs once per deploy BEFORE
# new web processes start (no boot race, unlike migrate-on-boot).
#
# NOTE: for Docker runtimes on Render, preDeployCommand only applies to
# Blueprint-synced services. Manual Dashboard services ignore render.yaml —
# the bin/docker-entrypoint boot-migrate safety net covers that case.

echo "[render-predeploy] running primary + cache + queue + cable migrates..."
bundle exec rails db:migrate db:migrate:cache db:migrate:queue db:migrate:cable
echo "[render-predeploy] done."
