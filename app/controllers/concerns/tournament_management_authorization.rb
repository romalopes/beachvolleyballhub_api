# Shared authorization for the tournament management surface (Phases 2/4).
#
# Site admins are checked against the REAL user so an admin who is impersonating
# a normal user keeps admin authority (the app-wide convention); organisation
# standing is checked against the EFFECTIVE user's Account via the canonical
# OrganisationAccess helper — owner/administrator/creator-member only. Coach and
# curator content authority deliberately does NOT extend to tournaments: the
# plan fixes administration to existing admin authority.
#
# Render-on-deny helpers return a boolean so actions must guard with
# `return unless authorize_tournament_management!`. The previous helper rendered
#403 without halting, which fell through to a second render and surfaced as
#500 instead of403.
module TournamentManagementAuthorization
  extend ActiveSupport::Concern

  private

  # Supports both route shapes: /tournaments/:id and the nested
  # /tournaments/:tournament_id/divisions[...] resources.
  def set_tournament
    @tournament = Tournament.find(params[:tournament_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Tournament not found" }, status: :not_found
  end

  def authorize_tournament_management!
    return true if @tournament && tournament_manager_for?(@tournament.organisation)

    render json: { error: "Forbidden" }, status: :forbidden
    false
  end

  def authorize_tournament_creation!(organisation)
    return true if tournament_manager_for?(organisation)

    render json: { error: "Forbidden" }, status: :forbidden
    false
  end

  def tournament_manager_for?(organisation)
    user = Current.user
    return false unless organisation && user
    return true if Current.real_user&.admin?

    OrganisationAccess.edits_record_by_membership?(organisation, user.account)
  end

  # RecordInvalid carries either model-validation messages (record.errors
  # populated) or a service-raised message (errors empty) — render whichever
  # exists so a422 never comes back with an empty error list.
  def invalid_record_errors(exception)
    exception.record.errors.full_messages.presence || [exception.message]
  end
end
