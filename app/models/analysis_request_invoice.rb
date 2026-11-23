class AnalysisRequestInvoice < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_invoices

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[AUD] }
  validates :status, inclusion: { in: %w[pending sent paid overdue cancelled refunded] }

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :paid, -> { where(status: "paid") }
  scope :overdue, -> { sent.where("sent_at < ?", 30.days.ago) }
  scope :unpaid, -> { where(status: %w[pending sent]) }

  def mark_sent!(external_reference: nil)
    update!(status: "sent", sent_at: Time.current, external_reference: external_reference)
  end

  def mark_paid!
    update!(status: "paid", paid_at: Time.current)
  end

  def mark_overdue!
    update!(status: "overdue")
  end

  def amount_aud
    "$#{'%.2f' % (amount_cents / 100.0)} AUD"
  end
end