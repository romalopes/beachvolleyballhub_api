class AnalysisPolicy
  def self.scope(actor)
    return Analysis.none if actor.nil?
    return Analysis.all if actor.admin? || actor.curator?

    # Creator and assigned coach scopes are simple where clauses (no joins)
    scope = Analysis.where(created_by_id: actor.id)
    coach_ids = actor.account&.coach_profile_ids || []
    scope = scope.or(Analysis.where(assigned_coach_profile_id: coach_ids)) if coach_ids.any?

    # Published participant scope uses a subquery to avoid incompatible joins with `or`
    player_ids = actor.account&.player_profile_ids || []
    if player_ids.any?
      participant_ids = Analysis.joins(:analysis_participants)
                                .where(analysis_participants: { player_profile_id: player_ids }, status: "published")
                                .select(:id)
      scope = scope.or(Analysis.where(id: participant_ids))
    end

    scope.distinct
  end

  def initialize(actor:, analysis:)
    @actor, @analysis = actor, analysis
  end

  def view? = self.class.scope(@actor).where(id: @analysis.id).exists?
  def manage? = oversight? || creator? || assigned_coach?
  def destroy? = @analysis.draft? ? manage? : @actor&.admin?
  def comment? = view? && (@analysis.published? || manage?)

  private

  def oversight? = @actor&.admin? || @actor&.curator?
  def creator? = @actor.present? && @analysis.created_by_id == @actor.id
  def assigned_coach? = @actor.present? && @analysis.assigned_coach_profile&.account_id == @actor.account&.id
end