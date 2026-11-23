# Phase 11 — Final Integration, Security Review, Regression & Production Readiness

**Goal:** End-to-end testing, security hardening, performance checks, deployment validation.

**Prerequisites:** Phase 10 complete ✅

---

## Checklist

### Integration Testing
- [ ] Full guest flow: submit → email → admin review → quote → accept → pay → work → complete → deliverable → notification
- [ ] Full authenticated flow: submit → same
- [ ] Guest claim → account → see history
- [ ] Coach workspace: assign → review → annotate → deliver → complete
- [ ] Admin: list → filter → accept/reject/quote/assign → internal notes
- [ ] Assessment session linking visible per role
- [ ] Cross-feature: existing Analysis feature unaffected

### Security Review
- [ ] Guest endpoints: honeypot + Turnstile + Rack::Attack throttles
- [ ] Guest access: token-only (no reference-only access)
- [ ] Authorization: Pundit policies cover all actions
- [ ] File uploads: content-type + size validation + virus scan (ClamAV if available)
- [ ] Signed URLs for deliverable download (expiry)
- [ ] No SQL injection / XSS vectors in search/filter params
- [ ] Rate limits on all mutating endpoints
- [ ] Audit logs via `LogService` for sensitive actions (payment override, coach assignment)

### Performance
- [ ] N+1 queries eliminated (bullet gem or manual `includes`)
- [ ] Pagination on all list endpoints (max 100/page)
- [ ] Video playback uses existing CDN/signed URLs
- [ ] Database indexes on all filter/sort columns
- [ ] Notification creation batched where possible

### Regression
- [ ] Full existing test suite passes (`bin/rails test`, `npm run test`)
- [ ] Existing Analysis feature works
- [ ] Notifications bell works
- [ ] Email delivery works (test mode)
- [ ] Billing/subscription unaffected

### Production Readiness
- [ ] Migrations are reversible
- [ ] Seeds for default `AnalysisPackage` records
- [ ] `AppSetting` keys documented for crew recipients, feature flags
- [ ] Environment variables documented: `ANALYSIS_REQUEST_VIDEO_MAX_BYTES`, `MAIL_TRANSPORT`, Turnstile keys
- [ ] Rollback plan: `db:migrate:down` for new tables
- [ ] Monitoring: error tracking (Sentry), slow query logs

### Documentation
- [ ] API docs updated (OpenAPI if used, or README)
- [ ] Frontend route map updated
- [ ] Admin user guide for workflow
- [ ] Coach user guide for workspace

---

## Final Verification Commands

```bash
# API
cd beachvolleyballhub_api
bin/rails test
bin/rails test:system  # if any

# Frontend
cd ../beachvolleyballhub
npm run test
npm run lint
npm run build

# Security
bundle exec brakeman
bundle exec bundler-audit check --update

# DB
bin/rails db:migrate:status
bin/rails db:seed  # idempotent
```

---

## Acceptance Criteria

- [ ] All integration scenarios work end-to-end
- [ ] Security audit passes (no critical/high findings)
- [ ] Performance: p95 < 500ms for list endpoints, < 1s for detail
- [ ] Zero regressions in existing features
- [ ] Deploy to staging → smoke test → deploy to production

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Stripe integration | Explicitly deferred (manual invoicing per plan) | Phase 1 scope; future phase |
| Load testing | Not in scope | Can be separate effort |