# A single-use invitation that lets a new user activate their Beach Volleyball Hub account.
# Distinct from ClaimInvitation which is for profile claims only.
#
#   - token_digest: SHA-256 hex digest of random token, unique, never exposed in URLs
#   - invitee_email: normalized (downcased, trimmed); optional at creation, required for email-sent invitations
#   - status: active | used | revoked | expired | declined
#   - expires_at: 7 days from creation by default
#   - invited_by: User who created the invitation (admin)
#   - used_by: User who accepted the invitation (set on acceptance)
#   - used_at: timestamp when invitation was accepted
#   - revoked_at: timestamp when invitation was revoked
#   - declined_at: timestamp when invitation was declined
class AccountInvitation < ApplicationRecord
  STATUSES = %w[active used revoked expired declined].freeze
  DEFAULT_EXPIRATION = 7.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :used_by, class_name: "User", optional: true

  # Normalized so redemption is an exact comparison (downcased, trimmed)
  normalizes :invitee_email, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :token_digest, presence: true, uniqueness: { scope: :status }
  validates :status, inclusion: { in: STATUSES }
  validates :expires_at, presence: true
  validates :invitee_email, format: { with: URI::MailTo::EMAIL_REGEXP },
                            allow_nil: true, allow_blank: true
  validates :used_at, presence: true, if: -> { status == "used" }
  validates :used_by, presence: true, if: -> { status == "used" }
  validates :revoked_at, presence: true, if: -> { status == "revoked" }
  validates :declined_at, presence: true, if: -> { status == "declined" }

  scope :active, -> { where(status: "active") }
  scope :by_email, ->(email) { where("LOWER(TRIM(invitee_email)) = ?", email.strip.downcase) }

  def effective_status(now: Time.current)
    status == "active" && expires_at <= now ? "expired" : status
  end

  # Single-use token generation (called by controller before creation)
  # Generates a secure hex digest from a random string
  def self.generate_token_digest
    # Secure random bytes, hexdigested
    Digest::SHA256.hexdigest(SecureRandom.hex(32))
  end

  # Check if invitation can be accepted (active, not expired, not used)
  def activatable?(now: Time.current)
    status == "active" && expires_at > now && used_by.nil?
  end

  def summary
    {
      id: id,
      invitee_email: invitee_email,
      emailed_at: emailed_at,
      status: effective_status,
      expires_at: expires_at,
      used_at: used_at,
      revoked_at: revoked_at,
      declined_at: declined_at,
      created_at: created_at
    }
  end
end