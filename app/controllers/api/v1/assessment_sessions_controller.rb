class Api::V1::AssessmentSessionsController < ApplicationController
  include ContentAuthorization
  include SubscriptionEntitlement

  # The roster's new-player control creates a profile-only record, so it only
  # exposes PlayerProfile attributes. `person` remains permitted in add_players
  # as a backwards-compatible shape for older clients.
  INLINE_PROFILE_ATTRIBUTES = InlineParticipantResolver::PROFILE_ATTRIBUTES
  INLINE_PERSON_ATTRIBUTES = InlineParticipantResolver::PERSON_ATTRIBUTES

  # Member actions use Pundit authorization; index uses policy_scope.
  before_action :set_assessment_session,
                only: %i[show update destroy add_players remove_players scores publish
                        withdraw restore ranking]

  # Track visibility before update to detect changes for audit logging
  before_action :track_visibility_before_update, only: :update
  # Premium: advanced assessments and player development (Coach plan). Opt-in per
  # environment via BILLING_ENFORCEMENT_ENABLED.
  before_action -> { require_subscription_feature!("advanced_assessments", owner: :personal) },
                only: %i[create update publish restore]

  # Share token endpoint: no authentication required (token in URL)
  allow_unauthenticated_access only: :show_by_share_token

  def index
    sessions = policy_scope(AssessmentSession)
                       .ordered
                       .includes(:assessment_definition, { coach_profile: :account }, :group,
                                 # Preloaded because `serialize` reads the session's
                                 # consolidations for every row; without this the list
                                 # would issue a query per session.
                                 consolidation_sessions: :ranking_consolidation,
                                 participants: { player_profile: :account },
                                 assessments: { assessment_category_scores: :assessment_category })
    render json: { assessment_sessions: sessions.map { |s| serialize(s) } }
  end

  def show
    authorize @assessment_session
    # Preloaded for the same reason as `index`: the detail screen lists the club
    # rankings this session feeds.
    @assessment_session.consolidation_sessions.includes(:ranking_consolidation).load
    render json: { assessment_session: serialize(@assessment_session) }
  end

  # GET /api/v1/assessment_sessions/:public_slug
  # Authenticated access via stable slug — uses same authorization as show
  def show_by_slug
    @assessment_session = AssessmentSession.find_by!(public_slug: params[:public_slug])
    authorize @assessment_session
    @assessment_session.consolidation_sessions.includes(:ranking_consolidation).load
    render json: { assessment_session: serialize(@assessment_session) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Not found" }, status: :not_found
  end

  # GET /api/v1/assessment_sessions/share/:share_token
  # UNAUTHENTICATED access via share token — only for unlisted sessions
  # Returns restricted payload per visibility rules
  def show_by_share_token
    # Skip authentication for this endpoint
    raw_token = params[:share_token]
    @assessment_session = AssessmentSession.find_by_share_token!(raw_token)

    # Don't use authorize here - this is a token-based access path
    # The model's find_by_share_token! already enforces unlisted + valid token

    # Prevent caching of shared content
    response.headers["Cache-Control"] = "private, no-store"

    @assessment_session.consolidation_sessions.includes(:ranking_consolidation).load
    render json: { assessment_session: serialize_share(@assessment_session) }
  rescue ActiveRecord::RecordNotFound
    # 404 for invalid, expired, revoked, or wrong-visibility tokens
    # No existence disclosure — always 404, never 403/401
    render json: { error: "Not found" }, status: :not_found
  end

  # POST /api/v1/assessment_sessions/:id/regenerate_share_link
  # Management auth required; session must be unlisted
  # :id parameter is the public_slug (not database ID)
  def regenerate_share_link
    @assessment_session = AssessmentSession.find_by!(public_slug: params[:id])

    # Return 422 if not unlisted (policy returns 403 for non-unlisted)
    unless @assessment_session.unlisted?
      return render json: { error: "Share link can only be generated for unlisted sessions" }, status: :unprocessable_entity
    end

    authorize @assessment_session, :regenerate_share_link?

    raw_token = @assessment_session.regenerate_share_token!
    @assessment_session.save!

    share_url = share_url_for(raw_token)

    log_share_link_regeneration(@assessment_session)

    render json: { share_url: share_url }, status: :ok
  end

  def create
    session_record = AssessmentSession.new(session_params)
    session_record.created_by = Current.user

    unless oversight_or_coach_of_record?(session_record.coach_profile)
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    # Save and group-roster seeding share one transaction, so a coach never
    # finds a draft that exists with an empty roster. See AssessmentSessionCreator.
    created = AssessmentSessionCreator.new(session: session_record).call

    if created.persisted?
      log_session_creation(created)
      render json: { assessment_session: serialize(created.reload) }, status: :created
    else
      render json: { errors: created.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @assessment_session
    return if @assessment_session.withdrawn? && !authorize_admin_only!(@assessment_session)
    return unless authorize_draft_edit!(@assessment_session)

    previous_visibility = @visibility_before_update
    if @assessment_session.update(session_params)
      log_session_update(@assessment_session, previous_visibility)
      render json: { assessment_session: serialize(@assessment_session) }
    else
      render json: { errors: @assessment_session.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # Add players to the roster, accepting both an existing `player_profile_id`
  # and a nested `person:` for someone who has no record yet. Resolution is
  # shared with training sessions (InlineParticipantResolver) so the identity
  # rules cannot drift between the two flows.
  # Delete a draft session. This is the one hard destroy in the resource, and it
  # is scoped on purpose: only a draft, and only by the coach of record or
  # oversight. `authorize_draft_edit!` already states both halves, so deleting
  # cannot drift from the rule that governs editing it.
  #
  # A published session is archival — D24 — so the 422 from that same guard is
  # the answer for it, not a missing route.
  # Delete a session.
  #
  # A draft is discardable by the coach of record, a curator or an admin — the
  # same rule that governs editing it, so the two cannot drift.
  #
  # A published session is normally archival, so deletion is admin-only: it exists
  # as the safety net for a publication that should never have happened, not as a
  # routine correction. Withdrawal is the ordinary way to retract a published
  # session, and it is reversible; this is not.
  def destroy
    authorize @assessment_session
    return unless authorize_session_destroy!

    session_name = @assessment_session.name
    @assessment_session.destroy!

    log_session_destruction(@assessment_session)

    render json: { message: "Session deleted", id: params[:id] }
  end

  # Drafts follow the edit rule. A withdrawn record is admin-only, being inert. A
  # published one is admin-only too, but as a deliberate exception to archival
  # history rather than as part of the normal workflow.
  def authorize_session_destroy!
    return authorize_admin_only!(@assessment_session) if @assessment_session.withdrawn?
    return authorize_admin_delete! if @assessment_session.published?

    authorize_draft_edit!(@assessment_session)
  end

  def withdraw
    authorize @assessment_session
    return unless authorize_withdraw!(@assessment_session, @assessment_session.coach_profile)

    # published_at is cleared: the session is no longer making a dated claim, and
    # the model requires the two to agree.
    @assessment_session.update!(status: "withdrawn", published_at: nil)

    render json: { assessment_session: serialize(@assessment_session.reload) }
  end

  # Bring a withdrawn session back. Admin only — see ContentAuthorization. The
  # destination is explicit: `draft` for work in progress, `published` to
  # republish (which re-runs the full publish checks rather than trusting the
  # original publication).
  def restore
    authorize @assessment_session
    return unless authorize_admin_only!(@assessment_session)

    to_status = params.require(:to_status)
    AssessmentSessionRestorer.new(@assessment_session, to_status: to_status).call

    render json: { assessment_session: serialize(@assessment_session.reload) }
  rescue AssessmentSessionRestorer::Error => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { errors: [ "to_status is required" ] }, status: :unprocessable_entity
  end

  def add_players
    authorize @assessment_session
    return unless authorize_draft_edit!(@assessment_session)

    rows = Array(
      params.permit(players: [
        :player_profile_id, :inclusion, :missing_reason,
        { profile: INLINE_PROFILE_ATTRIBUTES },
        { person: INLINE_PERSON_ATTRIBUTES }
      ])[:players]
    )
    return render json: { error: "No players supplied" }, status: :unprocessable_entity if rows.empty?

    result = AssessmentSessionRoster.new(
      session: @assessment_session,
      current_user: Current.user
    ).call(rows)

    if result.failed.any?
      render json: { errors: result.failed }, status: :unprocessable_entity
    else
      render json: {
        assessment_session: serialize(@assessment_session.reload),
        added: result.created.size
      }, status: :created
    end
  end

  def remove_players
    authorize @assessment_session
    return unless authorize_draft_edit!(@assessment_session)

    ids = Array(params[:player_profile_ids]).map(&:to_i)
    removed = @assessment_session.participants.where(player_profile_id: ids).destroy_all.size

    render json: { assessment_session: serialize(@assessment_session.reload), removed: removed }
  end

  # Save a whole score grid atomically. The request carries stable player and
  # discipline ids; totals and ranks are never accepted from the client.
  def scores
    authorize @assessment_session
    return unless authorize_draft_edit!(@assessment_session)

    rows = Array(params[:scores])
    if rows.empty?
      return render json: { error: "No scores supplied" }, status: :unprocessable_entity
    end

    AssessmentSessionScoreGrid.new(
      session: @assessment_session,
      current_user: Current.user
    ).call(rows)

    render json: { assessment_session: serialize(@assessment_session.reload) }
  rescue AssessmentSessionScoreGrid::Error => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  end

  # Publishing is the session's authority (S3): it validates that every
  # included player is complete, then promotes the session and its draft result
  # rows in one transaction (S2). An incomplete roster is a 422, never a
  # partial publish.
  def publish
    authorize @assessment_session
    return unless authorize_draft_edit!(@assessment_session)

    AssessmentSessionPublisher.new(@assessment_session).call

    render json: { assessment_session: serialize(@assessment_session.reload) }
  rescue AssessmentSessionPublisher::Error => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # Server-side ranking over complete rows only. Missing scores are reported
  # explicitly and never coerced to zero (D14); ties use standard competition
  # ranking (D15).
  def ranking
    authorize @assessment_session
    payload = AssessmentSessionRanking.new(@assessment_session).call

    render json: {
      assessment_session: serialize_session_identity(@assessment_session),
      ranking: payload[:ranking],
      incomplete: payload[:incomplete],
      excluded: payload[:excluded]
    }
  end

  private

  def set_assessment_session
    @assessment_session = AssessmentSession.find(params[:id])
  end

  # Writes are the union of two roles — oversight (curator/admin) or the coach
  # of record — and only while the session is a draft. Content management alone
  # is NOT enough: publishing ratings about a named player is a judgement, not
  # a catalogue edit. A published session is archival, so correcting it is a
  # withdrawal, not a silent edit.
  #
  # Returns true when the action may proceed; renders 403/422 and returns false
  # otherwise, so each action is a single `return unless ...` line instead of
  # the old guard-plus-`performed?` dance.
  def authorize_draft_edit!(session_record)
    unless oversight_or_coach_of_record?(session_record.coach_profile)
      render json: { error: "Forbidden" }, status: :forbidden
      return false
    end

    unless session_record.draft?
      render json: { error: "Only draft sessions can be modified" },
             status: :unprocessable_entity
      return false
    end

    true
  end

  def session_params
    params.expect(assessment_session: %i[
      name assessment_definition_id coach_profile_id group_id scheduled_on notes visibility
    ])
  end

  def serialize(session_record)
    ranking = AssessmentSessionRanking.new(session_record).call
    results = (ranking[:ranking] + ranking[:incomplete] + ranking[:excluded])
                .index_by { |row| row[:player_profile_id] }

    {
      id: session_record.id,
      public_slug: session_record.public_slug,
      visibility: session_record.visibility,
      name: session_record.name,
      status: session_record.status,
      status_label: session_record.status.capitalize(),
      scheduled_on: session_record.scheduled_on,
      notes: session_record.notes,
      published_at: session_record.published_at,
      created_by_id: session_record.created_by_id,
      coach_profile_id: session_record.coach_profile_id,
      coach_profile: {
        id: session_record.coach_profile_id,
        full_name: session_record.coach_profile.full_name,
        # Same rule as roster players: clients show "Account (profile)" when
        # the coach profile is claimed by an account.
        account_name: session_record.coach_profile.account&.full_name.presence
      },
      group_id: session_record.group_id,
      assessment_definition: serialize_definition(session_record.assessment_definition),
      group: session_record.group && { id: session_record.group.id, name: session_record.group.name },
      ranking: {
        ranking: ranking[:ranking],
        incomplete: ranking[:incomplete],
        excluded: ranking[:excluded]
      },
      participants: session_record.participants.map do |participant|
        profile = participant.player_profile
        {
          id: participant.id,
          player_profile_id: participant.player_profile_id,
          player_name: profile.full_name,
          # The linked account name, when the profile is claimed by an account.
          # Clients lead with it and keep the profile display name in
          # parentheses, so a staff label that drifted from the identity stays
          # visible. nil for a profile-only (staff-recorded) player.
          account_name: profile.account&.full_name.presence,
          inclusion: participant.inclusion,
          missing_reason: participant.missing_reason,
          result: results[participant.player_profile_id]
        }
      end,
      consolidations: serialize_consolidations(session_record)
    }
  end

  # The club rankings this session feeds. Carries `included_in_ranking` from the
  # snapshot row, because a coach retracting a session needs to see not just which
  # rankings mention it but whether their scores are actually in the numbers — a
  # withdrawn source stays attached to its ranking without contributing to it.
  def serialize_consolidations(session_record)
    session_record.consolidation_sessions
                  .includes(ranking_consolidation: :assessment_definition)
                  .sort_by { |join| -join.ranking_consolidation_id }
                  .map do |join|
      consolidation = join.ranking_consolidation
      {
        id: consolidation.id,
        name: consolidation.name,
        status: consolidation.status,
        status_label: consolidation.status_label,
        published_at: consolidation.published_at,
        included_in_ranking: join.included_in_ranking?
      }
    end
  end

  def serialize_session_identity(session_record)
    {
      id: session_record.id,
      name: session_record.name,
      status: session_record.status,
      scheduled_on: session_record.scheduled_on,
      assessment_definition: serialize_definition(session_record.assessment_definition)
    }
  end

  def serialize_definition(definition)
    return nil if definition.nil?

    {
      id: definition.id,
      name: definition.name,
      status: definition.status,
      assessment_categories: definition.assessment_categories.order(:position).map do |discipline|
        { id: discipline.id, label: discipline.label, weight: discipline.weight, position: discipline.position }
      end
    }
  end

  # Restricted serializer for share-token access (unlisted sessions)
  # Omits: notes, coach account_name, participant account_name, missing_reason, ranking, consolidations
  def serialize_share(session_record)
    ranking = AssessmentSessionRanking.new(session_record).call
    results = (ranking[:ranking] + ranking[:incomplete] + ranking[:excluded])
                .index_by { |row| row[:player_profile_id] }

    {
      id: session_record.id,
      public_slug: session_record.public_slug,
      visibility: session_record.visibility,
      name: session_record.name,
      status: session_record.status,
      status_label: session_record.status.capitalize,
      scheduled_on: session_record.scheduled_on,
      assessment_definition: serialize_definition(session_record.assessment_definition),
      coach_profile: {
        id: session_record.coach_profile_id,
        display_name: session_record.coach_profile.full_name
      },
      participants: session_record.participants.map do |participant|
        profile = participant.player_profile
        {
          id: participant.id,
          player_profile_id: participant.player_profile_id,
          player_name: profile.full_name,
          inclusion: participant.inclusion,
          result: results[participant.player_profile_id]
        }
      end
    }
  end

  def share_url_for(raw_token)
    frontend_url = ENV.fetch("FRONTEND_URL") do
      Rails.env.production? ? "https://beachvolleyballhub.com" : "http://localhost:5174"
    end.chomp("/")
    "#{frontend_url}/assessments/share/#{raw_token}"
  end

  private

  # Track visibility before update to detect changes for audit logging
  def track_visibility_before_update
    @visibility_before_update = @assessment_session.visibility
  end

  # Audit logging for session creation
  def log_session_creation(session)
    LogService.log(
      description: "Created assessment session \"#{session.name}\"",
      action: "create",
      method: request.request_method,
      user: Current.user,
      path: request.path,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      status: response.status,
      objects: [session]
    )
  end

  # Audit logging for session updates (especially visibility changes)
  def log_session_update(session, previous_visibility)
    if previous_visibility != session.visibility
      LogService.log(
        description: "Changed assessment session \"#{session.name}\" visibility from #{previous_visibility} to #{session.visibility}",
        action: "update_visibility",
        method: request.request_method,
        user: Current.user,
        path: request.path,
        request_id: request.request_id,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        status: response.status,
        objects: [session]
      )
    else
      LogService.log(
        description: "Updated assessment session \"#{session.name}\"",
        action: "update",
        method: request.request_method,
        user: Current.user,
        path: request.path,
        request_id: request.request_id,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        status: response.status,
        objects: [session]
      )
    end
  end

  # Audit logging for share link regeneration
  def log_share_link_regeneration(session)
    LogService.log(
      description: "Regenerated share link for assessment session \"#{session.name}\"",
      action: "regenerate_share_link",
      method: request.request_method,
      user: Current.user,
      path: request.path,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      status: response.status,
      objects: [session]
    )
  end

  # Audit logging for session destruction
  def log_session_destruction(session)
    LogService.log(
      description: "Deleted assessment session \"#{session.name}\"",
      action: "destroy",
      method: request.request_method,
      user: Current.user,
      path: request.path,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      status: response.status,
      objects: [session]
    )
  end
end
