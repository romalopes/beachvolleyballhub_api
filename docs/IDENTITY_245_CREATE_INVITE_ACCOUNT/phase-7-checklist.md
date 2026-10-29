# Phase 7: Rollback & Release Checklist

**Status:** Not Started ⭕

## 7.1 Environment Verification
- [ ] Mail transport configured (Brevo API key or Resend config)
- [ ] Database migration run: `rails db:migrate`
- [ ] Test suite passes locally
- [ ] Environment variables set (.env or Secrets)

## 7.2 Rollback Procedure
1. If migration fails partway: `rails db:rollback` to previous migration
2. If code issue: revert `admin_accounts_invitation_controller.rb`, `account_invitation_model.rb`, mailer
3. If mailer issue: disable new mailer, revert to existing pattern

## 7.3 Release Order
1. Feature branch with all 8 phases
2. Code review approval
3. Run full test suite
4. Staging deployment
5. Production deployment with feature flag if cautious
6. Monitor AdminActivity for 24h post-deploy