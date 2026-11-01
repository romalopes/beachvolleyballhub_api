# Authorization for player analyses.
#
# A view is permitted to the creator, an assigned coach, a published
# participant, or an admin/curator. Management (update/publish/archive) adds
# the creator/assigned-coach rules; hard delete of a published analysis is
# admin-only.
class AnalysisPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.nil?
      return scope.all if user.admin? || user.curator?

      # Creator and assigned-coach scopes are simple where clauses (no joins).
      relation = scope.where(created_by_id: user.id)
      coach_ids = user.account&.coach_profile_ids || []
      relation = relation.or(scope.where(assigned_coach_profile_id: coach_ids)) if coach_ids.any?

      # Published participant scope uses a subquery to avoid incompatible joins
      # with `or`.
      player_ids = user.account&.player_profile_ids || []
      if player_ids.any?
        participant_ids = scope.joins(:analysis_participants)
                               .where(analysis_participants: { player_profile_id: player_ids }, status: "published")
                               .select(:id)
        relation = relation.or(scope.where(id: participant_ids))
      end

      relation.distinct
    end
  end

  def index?   = true
  # Visibility check: renders 404 (not 403) via the app-wide handler so a
  # hidden analysis never discloses its existence.
  def show?    = visible?
  def create?  = content_manager?
  def manage?  = oversight? || creator? || assigned_coach?
  def update?  = manage?
  def publish? = manage?
  def archive? = manage?
  def link_assessment_session? = manage?
  def unlink_assessment_session? = manage?
  def destroy? = record.draft? ? manage? : admin?
  def comment? = visible? && (record.published? || manage?)

  private

  def visible?
    self.class::Scope.new(user, Analysis).resolve.where(id: record.id).exists?
  end

  def oversight? = admin? || curator?
  def creator? = user.present? && record.created_by_id == user.id
  def assigned_coach? = user.present? && record.assigned_coach_profile&.account_id == user.account&.id
end
