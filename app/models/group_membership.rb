# One subject's membership of a Group.
#
# Keyed on a polymorphic `memberable` — an Account, a PlayerProfile or a
# CoachProfile — mirroring `organisation_memberships` (§4.4). The subject is
# normally an Account, but an accountless PlayerProfile/CoachProfile recorded by
# staff can sit on a roster in its own right until a claim promotes it to its
# Account. `account_id` is kept alongside as a convenience/derivation column so
# the Account-only rules (uniqueness, ownership) can keep reading it.
#
# `status` is `pending` / `active` / `ended`. `pending` is a self-service join
# request awaiting the group's review (see `Group#approval_required?`) — it
# grants nothing until an approver activates it. It deliberately does *not*
# carry the invited / confirmed / attended vocabulary the previous version of
# this model rejected, and that reasoning still holds: attendance is evidence about one
# session, so it belongs on the session that observed it, not on the roster where
# it would be a stale opinion. Leaving a squad, though, is a fact about the roster
# itself, and §2.5 requires it to be recorded rather than deleted.
class GroupMembership < ApplicationRecord
  MEMBERABLE_TYPES = %w[Account PlayerProfile CoachProfile].freeze

  ROLES = %w[owner coach member].freeze
  STATUSES = %w[pending active ended].freeze

  belongs_to :group, inverse_of: :group_memberships
  belongs_to :account, optional: true
  belongs_to :memberable, polymorphic: true

  # An account-keyed row keeps its (group, account) uniqueness; the subject
  # index covers the profile-keyed case and the backfilled account rows.
  validates :account_id, uniqueness: { scope: :group_id }, allow_nil: true
  validates :memberable_type, inclusion: { in: MEMBERABLE_TYPES }
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :left_at_belongs_to_an_ended_membership
  validate :owner_cannot_leave
  # Ownership is Account-only (Group#owner? reads the active owner membership),
  # so a profile-keyed subject may never be granted the owner role.
  validate :owner_must_be_an_account

  # Keep Account writes compatible and repair a backfilled row when it is next
  # saved: writing `account:` still populates the subject column, exactly as
  # `OrganisationMembership#derive_memberable_from_account` does.
  before_validation :derive_memberable_from_account

  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :ended, -> { where(status: "ended") }
  # A signed-in account may be rostered directly or through one of its linked
  # player/coach profiles. Treat those as one subject when building a self-service
  # join catalogue, just as OrganisationMembership.for_user_subjects does.
  scope :for_user_subjects, ->(user) {
    account = user&.account
    if account.nil?
      none
    else
      relation = where(account_id: account.id).or(where(memberable: account))
      relation = relation.or(where(memberable_type: "PlayerProfile", memberable_id: account.player_profiles.select(:id)))
      relation.or(where(memberable_type: "CoachProfile", memberable_id: account.coach_profiles.select(:id)))
    end
  }
  # The one active owner, if there is one. The database guarantees at most one
  # (a partial unique index); this is how that fact is read back.
  scope :owners, -> { where(role: "owner", status: "active") }
  scope :ordered, -> { order(:id) }

  def owner?
    role == "owner" && status == "active"
  end

  def ended?
    status == "ended"
  end

  def pending?
    status == "pending"
  end

  def activate!
    update!(status: "active", joined_at: Time.current, left_at: nil)
  end

  # The name to show on a roster row, whichever subject the row is keyed on.
  def player_name
    case memberable
    when Account then memberable.full_name
    when PlayerProfile, CoachProfile then memberable.display_name
    else account&.full_name
    end
  end

  # Ends the membership rather than destroying it (§2.5). Called from the model so
  # the rule holds however the caller chose to leave.
  def end_membership!(at: Time.current)
    update!(status: "ended", left_at: at)
  end

  private

  # Ownership is Account-only. A profile-keyed row could never satisfy
  # Group#owner? (which reads the active owner membership's account), so granting
  # the role here would create an owner nothing can act on.
  def owner_must_be_an_account
    return unless role == "owner"
    return if memberable_type == "Account" || (memberable.nil? && account_id.present?)

    errors.add(:role, "may only be assigned to an account")
  end

  def derive_memberable_from_account
    self.memberable = account if account.present? && memberable.nil?
  end

  def owner_cannot_leave
    if persisted? && role_in_database == "owner" && status_in_database == "active" && status != "active"
      errors.add(:status, "cannot end the group owner's membership")
    end
  end

  # `left_at` belongs to `ended` and to nothing else, so the two can never
  # disagree about whether somebody actually left. Mirrors
  # organisation_memberships (§4.5); the database carries the same constraint.
  def left_at_belongs_to_an_ended_membership
    return if left_at.nil?
    return if status == "ended"

    errors.add(:left_at, "can only be set when the membership has ended")
  end
end
