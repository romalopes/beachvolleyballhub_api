class AnalysisRequest < ApplicationRecord
  WORKFLOW_STATUSES = %w[
    submitted under_review accepted rejected quoted awaiting_payment
    in_progress awaiting_submitter completed cancelled
  ].freeze

  PAYMENT_STATUSES = %w[
    unpaid invoice_sent paid overdue cancelled refunded complimentary
  ].freeze

  belongs_to :account, optional: true
  belongs_to :assigned_coach_profile, class_name: "CoachProfile", optional: true
  # The Analysis created when the team starts working on an approved request
  # (IDENTITY-265). Optional: older requests predate the link.
  belongs_to :analysis, optional: true
  # The submitter's player identity (IDENTITY-265). Resolved from the signed-in
  # user at submission time — created on the fly when the account has no
  # profile yet — so the analysis the team later produces is tied to a real
  # player, not just an email address.
  belongs_to :player_profile, optional: true
  belongs_to :package, class_name: "AnalysisPackage", foreign_key: :package_key, primary_key: :key, optional: true

  has_many :analysis_request_videos, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :analysis_request
  has_many :analysis_request_messages, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :analysis_request
  has_many :analysis_request_documents, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :analysis_request
  has_many :analysis_request_internal_notes, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :analysis_request
  has_many :analysis_request_invoices, dependent: :destroy, inverse_of: :analysis_request
  has_many :analysis_request_assessment_sessions, dependent: :destroy, inverse_of: :analysis_request
  has_many :assessment_sessions, through: :analysis_request_assessment_sessions
  has_many :analysis_request_notifications, class_name: "Notification", as: :notifiable, dependent: :destroy

  validates :reference, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 160 }
  validates :workflow_status, inclusion: { in: WORKFLOW_STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :guest_or_account_present
  validate :guest_email_format, if: -> { guest_email.present? }
  validate :guest_access_token_present_for_guest, if: -> { account_id.nil? }
  validate :assigned_coach_is_connected
  validate :package_is_available, if: -> { package_key.present? }

  scope :ordered, -> { order(submitted_at: :desc, id: :desc) }
  scope :for_account, ->(account) { where(account: account) }
  scope :guest_requests, -> { where(account_id: nil) }
  scope :submitted, -> { where(workflow_status: "submitted") }
  scope :under_review, -> { where(workflow_status: "under_review") }
  scope :accepted, -> { where(workflow_status: "accepted") }
  scope :in_progress, -> { where(workflow_status: "in_progress") }
  scope :completed, -> { where(workflow_status: "completed") }
  scope :unpaid, -> { where(payment_status: "unpaid") }
  scope :paid, -> { where(payment_status: "paid") }

  accepts_nested_attributes_for :analysis_request_videos, allow_destroy: true,
                                reject_if: :all_blank

  before_validation :generate_reference, on: :create
  before_validation :generate_guest_access_token, on: :create, if: -> { account_id.nil? }
  before_validation :set_submitted_at, on: :create

  def submit!
    update!(workflow_status: "submitted", submitted_at: Time.current)
  end

  def accept!(price_cents: nil)
    update!(workflow_status: "accepted", accepted_at: Time.current, price_cents: price_cents || self.price_cents)
  end

  def reject!(reason)
    update!(workflow_status: "rejected", rejected_at: Time.current, rejection_reason: reason)
  end

  def quote!(price_cents)
    update!(workflow_status: "quoted", price_cents: price_cents)
  end

  def mark_invoice_sent!(external_reference: nil)
    invoice = analysis_request_invoices.pending.first
    if invoice
      invoice.mark_sent!(external_reference: external_reference)
    else
      analysis_request_invoices.create!(amount_cents: price_cents, currency: "AUD", status: "sent", sent_at: Time.current, external_reference: external_reference)
    end
    update!(payment_status: "invoice_sent", invoice_sent_at: Time.current)
  end

  def mark_paid!
    invoice = analysis_request_invoices.sent.first
    invoice&.mark_paid!
    update!(payment_status: "paid", paid_at: Time.current)
    if %w[awaiting_payment accepted].include?(workflow_status)
      update!(workflow_status: "in_progress", work_started_at: Time.current)
    end
  end

  def mark_overdue!
    analysis_request_invoices.sent.each(&:mark_overdue!)
    update!(payment_status: "overdue")
  end

  def start_work_with_override!(reason)
    raise "Unauthorized" unless Current.user&.admin? || Current.user&.curator?
    update!(workflow_status: "in_progress", work_started_at: Time.current, payment_override: true, payment_override_reason: reason)
  end

  def start_work!
    update!(workflow_status: "in_progress", work_started_at: Time.current)
  end

  def complete!
    update!(workflow_status: "completed", completed_at: Time.current)
  end

  def cancel!
    update!(workflow_status: "cancelled", cancelled_at: Time.current, payment_status: "cancelled")
  end

  def guest? = account_id.nil?
  def authenticated? = account_id.present?

  # Human-readable submitter label for notifications and API payloads.
  def submitter_name
    account&.full_name.presence || guest_name.presence || "Guest"
  end

  # AUD display for emails and API payloads (prices are stored in cents).
  def price_aud
    return "Complimentary" if price_cents.to_i.zero?

    format("$%.2f AUD", price_cents / 100.0)
  end

  # Package label with a safe fallback for legacy rows.
  def package_name
    package&.name.presence || package_key.presence || "Custom scope"
  end

  def self.find_by_guest_access!(token)
    find_by!(guest_access_token: token)
  end

  private

  def guest_or_account_present
    errors.add(:base, "Must have either account or guest name/email") if account_id.nil? && (guest_name.blank? || guest_email.blank?)
  end

  def guest_email_format
    errors.add(:guest_email, "is not a valid email") unless guest_email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def guest_access_token_present_for_guest
    errors.add(:guest_access_token, "must be present for guest requests") if guest_access_token.blank?
  end

  def assigned_coach_is_connected
    return if assigned_coach_profile.nil? || assigned_coach_profile.account_id.present?
    errors.add(:assigned_coach_profile, "must be connected to an account")
  end

  def package_is_available
    errors.add(:package_key, "is not a valid active package") unless package&.active?
  end

  def generate_reference
    return if reference.present?
    year = Time.current.year
    last = AnalysisRequest.where("reference LIKE ?", "ANL-#{year}-%").order(:reference).last
    seq = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("ANL-%d-%04d", year, seq)
  end

  def generate_guest_access_token
    self.guest_access_token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_submitted_at
    self.submitted_at ||= Time.current
  end
end