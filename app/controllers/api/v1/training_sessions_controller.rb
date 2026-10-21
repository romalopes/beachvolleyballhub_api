module Api
  module V1
    # RESTful API for Training Sessions.
    #
    # Visibility and management are separate concerns:
    #   * index/show return only what the current user may see (drafts are
    #     private to coaches/curators/admins).
    #   * create/update/destroy require a training manager (coach, curator or
    #     admin). This is deliberately NOT based on `created_by_id`, because
    #     trainings are shared schedule resources.
    #
    # The creator is always derived from the authenticated request; a
    # `created_by_id` sent by the client is ignored.
    #
    # Serialization follows the existing project convention of Rails'
    # `render json:` with `only:`/`include:`. Drill data (description, visual
    # `definition` — which contains the steps — and skills) is read from the
    # Drill record and never copied into the training.
    class TrainingSessionsController < ApplicationController
      include ContentAuthorization

      CALENDAR_ATTRIBUTES = %i[id title starts_at ends_at location location_detail status visibility
                               created_by_id coach_profile_id training_series_id
                               training_template_id recurrence_key].freeze
      DETAIL_ATTRIBUTES = %i[id title description starts_at ends_at location location_detail status
                             visibility created_by_id created_at updated_at capacity level
                             organisation_id group_id coach_profile_id training_series_id
                             training_template_id recurrence_key original_starts_at override_fields
                             cancellation_reason cancelled_at cancelled_by_id].freeze
      FOCUS_ATTRIBUTES = %i[id skill_id custom_focus description position].freeze
      SESSION_DRILL_ATTRIBUTES = %i[id drill_id position duration_minutes notes].freeze
      PARTICIPANT_ATTRIBUTES = %i[id player_profile_id status notes].freeze
      # Fields a series occurrence may diverge on. Editing one of these through
      # the normal training form records an override so a later "update future"
      # does not silently overwrite the coach's change.
      SERIES_OVERRIDE_ATTRIBUTES = %i[
        title description location location_detail level capacity
        coach_profile_id group_id visibility
      ].freeze
      # Single source of truth: the inline-person allow-list belongs to the
      # resolver that consumes it, so the two cannot drift apart.
      INLINE_PERSON_ATTRIBUTES = InlineParticipantResolver::PERSON_ATTRIBUTES

      before_action :set_training_session, only: %i[show update destroy]
      before_action :require_training_manager!, only: %i[create update destroy]
      before_action :validate_index_filters!, only: :index

      def index
        render json: filtered_training_sessions,
               only: CALENDAR_ATTRIBUTES,
               methods: %i[status_label duration_minutes],
               include: { created_by: { only: %i[id name] } }
      end

      def show
        render_session_payload
      end

      def create
        @training_session = TrainingSession.new(training_session_params.merge(created_by: Current.user))
        persist
      end

      def update
        @training_session.assign_attributes(training_session_params)
        record_series_overrides!
        persist
      end

      def destroy
        @training_session.destroy
        head :no_content
      end

      private

      def persist
        if @training_session.save
          # Nested updates change positions; the associations preloaded in
          # set_training_session are stale after save, so re-read them in
          # their stored order.
          @training_session.reload
          render_session_payload status: action_name == "create" ? :created : :ok
        else
          render json: { errors: @training_session.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages.presence || [ duplicate_reference_message(e) ] }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique => e
        render json: { errors: [ duplicate_reference_message(e) ] }, status: :unprocessable_entity
      rescue ActiveRecord::InvalidForeignKey
        render json: { errors: [ "The training references a skill or drill that does not exist" ] },
               status: :unprocessable_entity
      rescue ActiveRecord::CheckViolation
        # Database-level backstop; the model validations normally catch these.
        render json: { errors: [ "The training contains invalid focus or drill data" ] },
               status: :unprocessable_entity
      end

      # Builds the detail payload explicitly so each participant can carry the
      # assessments recorded in this session (plan 4.2): `as_json(include:)`
      # can only render associations, and a participant's in-session ratings
      # are a pair of foreign keys (session + player), not an association.
      # Only published rows appear here — drafts and withdrawn rows are
      # working notes, reachable through the assessments endpoints.
      def render_session_payload(status: :ok)
        payload = @training_session.as_json(
          only: DETAIL_ATTRIBUTES,
          methods: %i[status_label duration_minutes],
          include: detail_includes
        )

        assessments_by_player = Assessment.active
                                  .where(training_session_id: @training_session.id)
                                  .ordered
                                  .includes(:category, :created_by, :coach_profile)
                                  .group_by(&:player_profile_id)
        Array(payload["training_session_participants"]).each do |participant|
          participant["assessments"] =
            Array(assessments_by_player[participant["player_profile_id"]]).map(&:metadata)
        end

        render json: payload, status: status
      end

      def filtered_training_sessions
        # mine=1 narrows the calendar to the current player's own sessions
        # ("my schedule"): sessions visible to them that they participate in.
        if params[:mine] == "1"
          profile = Current.user&.account&.player_profiles&.active&.order(:id)&.first
          return TrainingSession.none unless profile

          return TrainingSession.visible_to(Current.user).participated_by(profile).ordered
        end

        scope = TrainingSession
                  .visible_to(Current.user)
                  .starting_between(params[:starts_at_from], params[:starts_at_to])
                  .includes(:created_by)
                  .ordered
        scope = scope.where(status: params[:status]) if params[:status].present?
        if params[:training_series_id].present?
          scope = scope.where(training_series_id: params[:training_series_id])
        end
        scope
      end

      def set_training_session
        session = TrainingSession
                    .includes(:created_by, :training_series, :training_template, :coach_profile,
                              :organisation, :group,
                              training_focuses: { skill: :category },
                              training_session_drills: { drill: { skills: :category } },
                              training_session_participants: { player_profile: { account: :contact_detail } },
                              video_references: :video)
                    .find_by(id: params[:id])
        # A session the user may not see is reported as not found rather than
        # forbidden, so the API never reveals that it exists. All visibility
        # rules live in TrainingSession#visible_to_user?.
        unless session && session.visible_to_user?(Current.user)
          return render json: { error: "Training Session not found" }, status: :not_found
        end

        @training_session = session
      end

      def detail_includes
        {
          created_by: { only: %i[id name] },
          training_series: {
            only: %i[id training_template_id frequency interval weekdays starts_on ends_on
                     local_start_time duration_minutes time_zone status]
          },
          training_template: { only: %i[id name] },
          coach_profile: { only: %i[id display_name] },
          organisation: { only: %i[id name] },
          group: { only: %i[id name] },
          training_focuses: {
            only: FOCUS_ATTRIBUTES,
            methods: %i[label],
            include: {
              skill: {
                only: %i[id title slug description],
                include: { category: { only: %i[id name slug] } }
              }
            }
          },
          training_session_drills: {
            only: SESSION_DRILL_ATTRIBUTES,
            include: {
              drill: {
                except: %i[created_by_id],
                include: {
                  skills: {
                    only: %i[id title slug],
                    include: { category: { only: %i[id name slug] } }
                  }
                }
              }
            }
          },
          video_references: {
            only: VideoReferencesController::REFERENCE_ONLY,
            methods: VideoReferencesController::REFERENCE_METHODS,
            include: { video: { only: VideoReferencesController::VIDEO_ONLY, methods: VideoReferencesController::VIDEO_METHODS } }
          },
          training_session_participants: {
            only: PARTICIPANT_ATTRIBUTES,
            methods: %i[player_name account_connected],
            include: {
              player_profile: {
                only: %i[id preferred_position level],
                include: {
                  account: {
                    only: :id,
                    methods: :full_name,
                    include: { contact_detail: { only: %i[email phone] } }
                  }
                }
              }
            }
          }
        }
      end

      # Date/status filters are validated so bad input returns the standard
      # error shape instead of a database error.
      def validate_index_filters!
        errors = []
        errors << "starts_at_from is not a valid date" if invalid_date_param?(:starts_at_from)
        errors << "starts_at_to is not a valid date" if invalid_date_param?(:starts_at_to)
        if params[:status].present? && !TrainingSession::STATUSES.include?(params[:status])
          errors << "status is not included in the list"
        end

        render json: { errors: errors }, status: :unprocessable_entity if errors.any?
      end

      def invalid_date_param?(key)
        return false if params[key].blank?

        Time.zone.parse(params[key].to_s).nil?
      rescue ArgumentError
        true
      end

      # Records only the fields this request actually changed. Comparing with
      # the effective defaults means resetting a field to the series value
      # removes its override instead of leaving a stale flag.
      def record_series_overrides!
        series = @training_session.training_series
        return if series.nil? || series.training_template.nil?

        defaults = series.training_template.defaults_for_series.merge(series.defaults)
        overrides = (@training_session.override_fields || {}).dup

        SERIES_OVERRIDE_ATTRIBUTES.each do |attribute|
          next unless @training_session.will_save_change_to_attribute?(attribute)

          key = attribute.to_s
          if @training_session.public_send(attribute) == defaults[attribute]
            overrides.delete(key)
          else
            overrides[key] = true
          end
        end

        record_time_overrides!(overrides, series)

        @training_session.override_fields = overrides
      end

      # A moved occurrence keeps its recurrence_key but must still count as an
      # override so a split cannot silently destroy the coach's change.
      def record_time_overrides!(overrides, series)
        original = @training_session.original_starts_at
        return if original.blank?

        if @training_session.will_save_change_to_attribute?(:starts_at)
          if @training_session.starts_at == original
            overrides.delete("starts_at")
          else
            overrides["starts_at"] = true
          end
        end

        return unless @training_session.will_save_change_to_attribute?(:ends_at)

        expected_end = original + series.duration_minutes.minutes
        if @training_session.ends_at == expected_end
          overrides.delete("ends_at")
        else
          overrides["ends_at"] = true
        end
      end

      def training_session_params
        permitted = params.require(:training_session).permit(
          :title, :description, :starts_at, :ends_at, :location, :location_detail,
          :capacity, :level, :organisation_id, :group_id, :coach_profile_id,
          :status,
          training_focuses_attributes: %i[id skill_id custom_focus description position _destroy],
          training_session_drills_attributes: %i[id drill_id position duration_minutes notes _destroy],
          training_session_participants_attributes: [
            :id, :player_profile_id, :status, :notes, :_destroy,
            { person: INLINE_PERSON_ATTRIBUTES }
          ]
        )

        # A participant row may carry inline `person:` attributes instead of a
        # `player_profile_id` — the "coach adds a player who does not have an
        # account yet" workflow. The sequence lives in InlineParticipantResolver
        # because the assessment-session form needs exactly the same one.
        InlineParticipantResolver.new(created_by: Current.user)
                                .call(permitted[:training_session_participants_attributes])
        fill_missing_positions!(permitted, :training_focuses_attributes)
        fill_missing_positions!(permitted, :training_session_drills_attributes)
        permitted
      end

      # The submitted array order is the intended order. Explicit positions are
      # honoured; rows that omit one fall back to their index so the final
      # order is always persisted.
      def fill_missing_positions!(permitted, key)
        rows = permitted[key]
        return if rows.blank?

        rows.each_with_index do |row, index|
          row["position"] = index if row["position"].blank?
        end
      end

      def duplicate_reference_message(error)
        case error.message
        when /index_training_session_participants_on_session_and_player/
          "Players must be unique within a training session"
        when /index_training_session_drills_on_session_and_drill/
          "Drills must be unique within a training session"
        when /index_training_focuses_on_session_and_skill/
          "Skills must be unique within a training session"
        when /index_training_sessions_on_series_and_recurrence_key/
          "This occurrence already exists in the series"
        else
          "The training contains duplicate references"
        end
      end
    end
  end
end
