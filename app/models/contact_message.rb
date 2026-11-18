# A public contact enquiry submitted from the Contact form (IDENTITY-259).
#
# The channel is deliberately anonymous: there is no `user_id`, and a message is
# never associated with a PlayerProfile, CoachProfile, Account, Organisation,
# TrainingSession or Tournament from form input. Authorised platform staff read
# it through Settings → Contact Messages; no public route can reach the body.
#
# Content is stored as plain text and is escaped wherever it is rendered (API
# consumer, HTML email). `emailed_at` / `notified_at` record delivery so a
# retried job cannot send or notify twice; they are never accepted from a client.
class ContactMessage < ApplicationRecord
  # BeachVolleyballHub support categories. This is the single allowlist: the
  # public API validates against it and publishes it (labels included) through
  # GET /api/v1/contact_messages/options.
  CONTACT_TYPES = %w[
    general account_access coaching organisation training_tournament
    location technical_support partnership feedback other
  ].freeze

  CONTACT_TYPE_LABELS = {
    "general" => "General enquiry",
    "account_access" => "Account or login support",
    "coaching" => "Coaching enquiry",
    "organisation" => "Organisation or club enquiry",
    "training_tournament" => "Training or tournament enquiry",
    "location" => "Court or location information",
    "technical_support" => "Technical support",
    "partnership" => "Business or partnership",
    "feedback" => "Feedback or suggestion",
    "other" => "Other"
  }.freeze

  # Inbox states. `archived` is a state, not a deletion: nothing in the product
  # hard-deletes a contact message in this release.
  STATUSES = %w[unread read archived].freeze

  MAX_NAME_LENGTH = 120
  MAX_EMAIL_LENGTH = 254
  MAX_SUBJECT_LENGTH = 180
  MAX_MESSAGE_LENGTH = 10_000

  # Anchored on purpose. URI::MailTo::EMAIL_REGEXP is unanchored, so it would
  # accept an address with an embedded CR/LF — exactly the shape used for email
  # header injection.
  EMAIL_FORMAT = /\A#{URI::MailTo::EMAIL_REGEXP}\z/

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  # Email is normalised like User#email_address so the inbox search and the
  # Reply-To header always see the same lexical value.
  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :subject, with: ->(value) { value.to_s.strip.presence }
  normalizes :contact_type, with: ->(value) { value.to_s.strip.downcase.presence }
  # A message is multi-line by nature: only the surrounding whitespace goes.
  normalizes :message, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :email, presence: true,
                    length: { maximum: MAX_EMAIL_LENGTH },
                    format: { with: EMAIL_FORMAT, message: "is not a valid email address" }
  validates :contact_type, presence: true, inclusion: { in: CONTACT_TYPES }
  validates :subject, presence: true, length: { maximum: MAX_SUBJECT_LENGTH }
  validates :message, presence: true, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # A CR/LF in a name or subject becomes a header-injection attempt the moment
  # the value reaches an email header. Reject it at the boundary instead of
  # relying on every downstream mail library.
  validate :no_control_characters

  scope :by_recency, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(status: "unread") }
  scope :read_messages, -> { where(status: "read") }
  scope :archived, -> { where(status: "archived") }
  scope :not_archived, -> { where.not(status: "archived") }

  # Free-text search over the fields staff actually search: sender name, address
  # and subject. `sanitize_sql_like` keeps `%` and `_` literal, so this is a
  # parameterised LIKE, never interpolated SQL.
  scope :matching, ->(term) {
    cleaned = term.to_s.strip
    next all if cleaned.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(cleaned)}%"
    where("name ILIKE :pattern OR email ILIKE :pattern OR subject ILIKE :pattern", pattern: pattern)
  }

  def contact_type_label
    CONTACT_TYPE_LABELS.fetch(contact_type, contact_type.to_s.humanize)
  end

  def unread? = status == "unread"
  def read? = status == "read"
  def archived? = status == "archived"

  # --- Status transitions -----------------------------------------------------
  # All three are idempotent, so the SPA may retry a PATCH safely.
  #
  # read/unread also *unarchive*: an archived message somebody is working on
  # again must return to the ordinary inbox rather than appear in both the
  # "unread" tab and the "archived" tab.

  def mark_read!
    return self if status == "read"

    update!(status: "read", read_at: read_at || Time.current, archived_at: nil)
    self
  end

  def mark_unread!
    return self if status == "unread"

    update!(status: "unread", read_at: nil, archived_at: nil)
    self
  end

  def archive!
    return self if status == "archived"

    update!(status: "archived", archived_at: archived_at || Time.current)
    self
  end

  # Applies a validated status from the API. An unknown value adds a model error
  # and raises, so the caller renders the standard `{ errors: [...] }` contract
  # rather than silently ignoring the request.
  def apply_status!(new_status)
    case new_status.to_s
    when "unread" then mark_unread!
    when "read" then mark_read!
    when "archived" then archive!
    else
      errors.add(:status, :inclusion, value: new_status)
      raise ActiveRecord::RecordInvalid, self
    end
  end

  private

  def no_control_characters
    %i[name subject email].each do |field|
      value = public_send(field)
      next if value.blank?
      next unless value.match?(/[\r\n\t\v\f\x00]/)

      errors.add(field, "must not contain control characters")
    end
  end
end
