# Authorization rules for assessment-session operations shared by other domains.
class AssessmentSessionPolicy < ApplicationPolicy
  # Linking an assessment session exposes its result context through an analysis,
  # so only the established session managers may create that relationship.
  def link_to_analysis?
    admin? || curator? || creator? || assigned_coach?
  end

  # Viewing an assessment session — governed by the visibility matrix.
  # Public: any authenticated user
  # Unlisted: NOT via standard path (token path handled in controller)
  # Internal: organisation members + assigned coach + involved players
  # Private: assigned coach + admin (+ curator per oversight)
  def show?
    return false unless user.present?

    # Management authority always grants view (coach of record, admin, curator)
    return true if management_authority?

    case record.visibility
    when "public"
      true
    when "internal"
      internal_access?
    when "private"
      false # only management_authority gets here, already returned true above
    when "unlisted"
      false # unlisted uses token path, not standard auth
    else
      false
    end
  end

  # Alias for show_by_slug action - uses same logic as show?
  def show_by_slug?
    show?
  end

  # Management actions — coach of record + admin (+ curator per oversight)
  def update?       = management_authority?
  def destroy?      = management_authority? && record.draft? # published = admin only via controller
  def add_players?  = management_authority?
  def remove_players? = management_authority?
  def scores?       = management_authority?
  def publish?      = management_authority?
  def withdraw?     = management_authority?
  def restore?      = admin? # only admin per existing rule

  # Visibility management — coach of record + admin (+ curator per oversight)
  def manage_visibility? = management_authority?

  # Share link regeneration — must be unlisted + management authority
  def regenerate_share_link?
    management_authority? && record.unlisted?
  end

  # Ranking access — management authority for detail, visibility-aware for share
  def ranking?
    management_authority? || show?
  end

  # Scope for index action
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      # Oversight (curator, admin): all sessions
      return scope.all if user.curator? || user.admin?

      # Coaches: own sessions (where coach of record) + public sessions
      if user.coach?
        coach_profile_ids = user.account&.coach_profiles&.pluck(:id) || []
        return scope.where(visibility: "public") if coach_profile_ids.empty?

        # Coach of record sessions + public sessions
        return scope.where("coach_profile_id IN (?) OR visibility = 'public'", coach_profile_ids)
      end

      # Players: involved sessions (internal/public only) + public sessions
      if user.player?
        player_profile_ids = user.account&.player_profiles&.pluck(:id) || []
        return scope.none if player_profile_ids.empty?

        involved_session_ids = AssessmentSessionParticipant
                                 .where(player_profile_id: player_profile_ids, inclusion: "included")
                                 .pluck(:assessment_session_id)

        return scope.none if involved_session_ids.empty?

        # Use a single WHERE clause with subquery logic
        return scope.where("visibility = 'public' OR (visibility = 'internal' AND id IN (?))", involved_session_ids)
      end

      # Others: public only
      scope.where(visibility: "public")
    end
  end

  private

  def creator? = user.present? && record.created_by_id == user.id

  # Coach of record: the coach_profile has an account that matches the current user's account
  def assigned_coach?
    user.present? && record.coach_profile&.account_id == account&.id
  end

  # Management authority: coach of record OR admin OR curator (oversight)
  def management_authority?
    assigned_coach? || admin? || curator?
  end

  # Internal access: organisation members + assigned coach + involved players
  # (assigned_coach? already handled by management_authority?, but kept for clarity)
  def internal_access?
    return true if assigned_coach?

    # Involved player (included participants only)
    if user.player? && user.account.present?
      player_profile_ids = user.account.player_profiles.pluck(:id)
      return true if record.participants.included.where(player_profile_id: player_profile_ids).exists?
    end

    # Organisation member: active member of any organisation the coach of record belongs to
    if user.account.present? && record.coach_profile.present?
      coach_org_ids = record.coach_profile
                             .organisation_memberships
                             .active
                             .select(:organisation_id)
      return true if OrganisationMembership
                       .active
                       .where(account_id: user.account.id, organisation_id: coach_org_ids)
                       .exists?
    end

    false
  end
end
