# Authorization boundary shared by PlayerProfile and CoachProfile.
#
# Pundit calls this policy with `(user, record)`. The keyword arguments remain
# temporarily supported because model/service callers are being migrated in
# separate slices.
class ProfilePolicy < ApplicationPolicy
  def initialize(user = nil, record = nil, actor: nil, profile: nil)
    user = actor if actor
    record = profile if profile
    super(user, record)
    @account = user.is_a?(Account) ? user : user&.account
    @user = user.is_a?(User) ? user : user&.user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all if manager?

      account = user.is_a?(Account) ? user : user&.account
      return scope.where(account_id: account.id) if account
      return scope.where(created_by_id: user.id) if user.is_a?(User)

      scope.none
    end

    private

    def manager?
      account = user.is_a?(Account) ? user : user&.account
      actor = user.is_a?(User) ? user : user&.user
      account&.admin? || account&.curator? || account&.coach? ||
        actor&.admin? || actor&.curator? || actor&.coach? || false
    end
  end

  def index? = manager? || @account.present?
  def can_view_collection? = index?
  def create? = create_player? || create_coach?
  def create_player? = admin? || curator? || coach? || player?
  def create_coach? = admin? || curator? || coach?

  def show? = view?

  def view?
    return false unless record && user
    return true if linked_account?(record)
    return true if admin? || curator?
    return true if ProfileOwnership.created_by?(record, user)
    return true if record.visibility == "shared" && training_manager?
    return true if player_peer_access?

    false
  end

  def update?
    record.present? && user.present? &&
      (admin? || curator? || ProfileOwnership.created_by?(record, user))
  end

  def change_visibility?
    record.present? && user.present? &&
      (admin? || ProfileOwnership.created_by?(record, user))
  end

  def invite?
    return false unless record
    return true if admin? || curator?

    coach? && ProfileOwnership.created_by?(record, user)
  end

  def review_claim?
    return false unless record
    return true if admin?

    coach? && ProfileOwnership.created_by?(record, user)
  end

  def unlink? = admin? || curator?
  def merge? = admin? || curator?
  def archive? = update?
  def destroy? = update?
  def manager? = admin? || curator? || coach?

  # Compatibility for callers that have not yet moved to `policy_scope`.
  def self.scope(relation, actor:)
    Scope.new(actor, relation).resolve
  end

  private

  def linked_account?(profile)
    ProfileOwnership.linked_to?(profile, user)
  end

  def player_peer_access?
    return false unless record.is_a?(PlayerProfile) && training_manager? && @account

    organisation_ids = OrganisationMembership.active.where(account_id: @account.id).pluck(:organisation_id)
    return false if organisation_ids.empty?

    peer_account_ids = OrganisationMembership.active
                                             .where(organisation_id: organisation_ids)
                                             .where.not(account_id: nil)
                                             .pluck(:account_id)
    peer_account_ids.include?(record.account_id)
  end

  def admin? = @account&.admin? || @user&.admin? || false
  def curator? = @account&.curator? || @user&.curator? || false
  def coach? = @account&.coach? || @user&.coach? || false
  def player? = @account&.player? || @user&.player? || false
  def training_manager? = manager?
end
