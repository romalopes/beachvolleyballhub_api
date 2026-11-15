# Scheduled reconciliation between local billing state and Stripe
# (IDENTITY-116, Phase 5).
#
# Webhooks are the primary path; this job is the safety net for a delivery that
# was lost or permanently rejected. It is safe to run repeatedly: every repair is
# idempotent and goes through the same webhook processor as a live event.
#
# When billing is not configured (e.g. a staging box without Stripe keys) the job
# logs and exits rather than failing the queue.
class BillingReconciliationJob < ApplicationJob
  queue_as :default

  def perform(limit: 500)
    summary = Billing::ReconciliationService.new(limit: limit).call
    Rails.logger.info("[billing] reconciliation #{summary.to_h.to_json}")
    summary.to_h
  rescue Billing::Errors::NotConfigured => e
    Rails.logger.info("[billing] reconciliation skipped: #{e.message}")
    { skipped: true, reason: e.message }
  end
end
