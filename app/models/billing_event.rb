# Webhook receipt and processing audit (IDENTITY-116, Phase 5).
#
# `stripe_event_id` is unique: Stripe delivers at least once, so idempotency is a
# database guarantee rather than a hope. The row also records what happened —
# processed, skipped as a duplicate, or failed with an error message — which is
# what the admin "webhook health" view and the reconciliation job inspect.
#
# The payload is stored for diagnosis. Stripe event payloads contain identifiers
# and amounts but not card data; secrets and signature headers are never stored.
class BillingEvent < ApplicationRecord
  STATUSES = %w[received processed failed skipped].freeze

  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :failures, -> { where(status: "failed") }
  scope :unprocessed, -> { where(status: "received") }

  def processed?
    status == "processed"
  end

  def failed?
    status == "failed"
  end

  def skipped?
    status == "skipped"
  end

  def mark_processed!(now = Time.current)
    update!(status: "processed", processed_at: now, error_message: nil)
  end

  def mark_skipped!(reason = nil)
    update!(status: "skipped", processed_at: Time.current, error_message: reason)
  end

  def mark_failed!(message)
    update!(status: "failed", processed_at: Time.current,
            error_message: message.to_s.truncate(2000), attempts: attempts + 1)
  end

  def record_attempt!
    increment!(:attempts)
  end
end
