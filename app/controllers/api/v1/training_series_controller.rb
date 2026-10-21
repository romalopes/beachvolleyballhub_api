module Api
  module V1
    # Recurring training series: preview, creation, browsing and occurrence
    # listing. All actions require a training manager, matching the existing
    # training rule; organisation/group ids are schedule metadata, not an
    # authorization scope.
    #
    # Bulk operations, stopping, future edits and splitting are added in later
    # phases of the recurring-training rollout.
    class TrainingSeriesController < ApplicationController
      include ContentAuthorization
      include Pagination
      include RecurringTrainingAuthorization

      SERIES_ATTRIBUTES = %i[
        id training_template_id organisation_id created_by_id frequency interval
        weekdays starts_on ends_on local_start_time duration_minutes time_zone
        status generated_through last_generated_at stopped_at stopped_reason
        created_at updated_at
      ].freeze

      SESSION_ATTRIBUTES = %i[
        id title starts_at ends_at location location_detail status visibility
        capacity level training_series_id training_template_id organisation_id
        group_id coach_profile_id recurrence_key original_starts_at override_fields
        cancellation_reason cancelled_at cancelled_by_id created_at updated_at
      ].freeze

      before_action :require_training_manager!
      before_action :validate_index_filters!, only: :index
      before_action :validate_session_filters!, only: :sessions
      before_action :set_training_series, only: %i[
        show sessions bulk_cancel bulk_delete stop cancel_future update_future split
      ]

      # POST /api/v1/training_series/preview
      # Builds the same unsaved series that POST /training_series would save and
      # returns the expanded dates. Performs no writes.
      def preview
        template = find_template
        return unless template

        series = TrainingSeriesCreator.build_series(
          template: template, attributes: series_params, actor: Current.user
        )

        render json: TrainingSeriesPreview.new(template: template, series: series).call
      end

      def index
        records, meta = paginate(series_scope)

        render json: {
          data: records.map { |series| series_payload(series) },
          meta: meta
        }
      end

      def show
        render json: {
          training_series: series_payload(@training_series).merge(show_metrics(@training_series))
        }
      end

      def create
        template = find_template
        return unless template

        if template.archived?
          return render json: { errors: [ "Archived templates cannot be scheduled" ] },
                        status: :unprocessable_entity
        end

        result = TrainingSeriesCreator.call(
          template: template, attributes: series_params, actor: Current.user
        )

        if result.success?
          log_action("create", "Scheduled training series for #{template.name}",
                     [ result.series ])
          render json: {
            training_series: series_payload(result.series),
            generation: generation_payload(result.generator_result)
          }, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/training_series/:id/sessions
      # Occurrences are paginated (the generator caps a series at 200).
      def sessions
        scope = @training_series.training_sessions
                                .includes(:coach_profile)
                                .order(:starts_at, :id)

        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where("starts_at >= ?", @sessions_from) if @sessions_from
        scope = scope.where("starts_at <= ?", @sessions_to) if @sessions_to

        records, meta = paginate(scope)

        render json: {
          data: records.map { |session| occurrence_payload(session) },
          meta: meta
        }
      end

      # POST /api/v1/training_series/:id/bulk_cancel
      def bulk_cancel
        result = TrainingSeriesCanceller.new(
          @training_series,
          session_ids: params[:session_ids],
          reason: params[:reason],
          actor: Current.user,
          notify_participants: boolean_param(:notify_participants)
        ).call

        if result.affected.any?
          log_action("bulk_cancel",
                     "Cancelled #{result.affected.size} occurrences: #{params[:reason]}",
                     [ @training_series ])
        end

        render json: {
          affected_ids: result.affected_ids,
          skipped: result.skipped,
          errors: result.errors
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      # POST /api/v1/training_series/:id/bulk_delete
      def bulk_delete
        result = TrainingSeriesDeleter.new(
          @training_series, session_ids: params[:session_ids]
        ).call

        if result.deleted_ids.any?
          log_action("bulk_delete", "Deleted #{result.deleted_ids.size} draft occurrences",
                     [ @training_series ])
        end

        render json: {
          deleted_ids: result.deleted_ids,
          skipped: result.skipped,
          errors: result.errors
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      # POST /api/v1/training_series/:id/stop
      def stop
        result = TrainingSeriesStopper.new(
          @training_series, reason: params[:reason], actor: Current.user
        ).call

        if result.success?
          log_action("stop",
                     "Stopped training series recurrence: #{params[:reason].presence || 'no reason given'}",
                     [ result.series ])
          render json: {
            training_series: series_payload(result.series).merge(show_metrics(result.series)),
            changed: result.changed
          }
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/training_series/:id/cancel_future
      def cancel_future
        from = required_date_param(:from)
        return unless from

        result = TrainingSeriesFutureCanceller.new(
          @training_series,
          from: from,
          reason: params[:reason],
          actor: Current.user,
          notify_participants: boolean_param(:notify_participants)
        ).call

        if result.affected.any?
          log_action("cancel_future",
                     "Cancelled #{result.affected.size} future occurrences: #{params[:reason]}",
                     [ @training_series ])
        end

        render json: {
          affected_ids: result.affected_ids,
          skipped: result.skipped,
          errors: result.errors
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      # POST /api/v1/training_series/:id/update_future
      def update_future
        from = required_date_param(:effective_from)
        return unless from

        result = TrainingSeriesFutureEditor.new(
          @training_series,
          from: from,
          changes: update_future_changes,
          overwrite_overrides: boolean_param(:overwrite_overrides),
          actor: Current.user
        ).call

        if result.updated_ids.any?
          log_action("update_future", "Updated #{result.updated_ids.size} future occurrences",
                     [ @training_series ])
        end

        render json: {
          updated_ids: result.updated_ids,
          skipped: result.skipped,
          errors: result.errors
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      # POST /api/v1/training_series/:id/split
      def split
        from = required_date_param(:effective_from)
        return unless from

        result = TrainingSeriesSplitter.new(
          @training_series,
          from: from,
          attributes: split_recurrence_params,
          reason: params[:reason],
          actor: Current.user,
          discard_overrides: boolean_param(:discard_overrides)
        ).call

        if result.success?
          log_action("split",
                     "Split training series at #{from.iso8601}: #{params[:reason]}",
                     [ result.old_series, result.new_series ])
          render json: {
            training_series: series_payload(result.old_series),
            new_series: series_payload(result.new_series),
            destroyed_count: result.destroyed_count,
            generation: generation_payload(result.generator_result)
          }
        else
          render json: { errors: result.errors, blockers: result.blockers },
                 status: :unprocessable_entity
        end
      end

      private

      def series_scope
        scope = TrainingSeries
                  .includes(:training_template, :organisation, :created_by)
                  .order(starts_on: :desc, id: :desc)

        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(training_template_id: params[:training_template_id]) if params[:training_template_id].present?
        scope = scope.where(organisation_id: params[:organisation_id]) if params[:organisation_id].present?
        scope = scope.where("ends_on >= ?", @from) if @from
        scope = scope.where("starts_on <= ?", @to) if @to
        scope = scope.where("ends_on >= ?", Date.current) if params[:upcoming] == "1"
        scope
      end

      def show_metrics(series)
        counts = series.training_sessions.group(:status).count
        next_occurrence = series.training_sessions
                                 .where(status: "scheduled")
                                 .where("starts_at >= ?", Time.current)
                                 .minimum(:starts_at)

        {
          occurrence_count: counts.values.sum,
          scheduled_count: counts.fetch("scheduled", 0),
          cancelled_count: counts.fetch("cancelled", 0),
          completed_count: counts.fetch("completed", 0),
          draft_count: counts.fetch("draft", 0),
          next_occurrence_at: next_occurrence
        }
      end

      def occurrence_payload(session)
        session.as_json(
          only: SESSION_ATTRIBUTES,
          methods: %i[status_label],
          include: { coach_profile: { only: %i[id display_name] } }
        ).merge(
          "overridden" => session.overridden?,
          "deletable" => session.deletable_occurrence?,
          "cancellable" => session.cancellable?
        )
      end

      def generation_payload(result)
        {
          created_count: result.created_count,
          already_present: result.already_present,
          errors: result.errors
        }
      end

      def find_template
        template = TrainingTemplate.find_by(id: series_params[:training_template_id])
        return template if template

        render json: { errors: [ "Training template is required" ] },
               status: :unprocessable_entity
        nil
      end

      def set_training_series
        @training_series = TrainingSeries
                             .includes(:training_template, :organisation, :created_by)
                             .find_by(id: params[:id])

        return if @training_series

        render json: { error: "Training series not found" }, status: :not_found
      end

      def series_payload(series)
        series.as_json(
          only: SERIES_ATTRIBUTES,
          methods: %i[defaults],
          include: {
            training_template: {
              only: %i[id name location location_detail capacity duration_minutes visibility status]
            },
            organisation: { only: %i[id name] },
            created_by: { only: %i[id name] }
          }
        ).merge(
          "local_start_time" => series.local_start_time&.strftime("%H:%M"),
          "next_generation_start" => series.next_generation_start&.iso8601,
          "completed" => series.completed?
        )
      end

      def series_params
        params.require(:training_series).permit(
          :training_template_id, :organisation_id, :frequency, :interval,
          :starts_on, :ends_on, :local_start_time, :duration_minutes, :time_zone,
          weekdays: [],
          overrides: TrainingSeriesCreator::OVERRIDABLE_DEFAULTS
        )
      end

      def update_future_changes
        raw = params[:changes]
        raw = raw.permit(*TrainingSeriesFutureEditor::ALLOWED_FIELDS) if raw.respond_to?(:permit)
        raw.respond_to?(:to_h) ? raw.to_h : {}
      end

      def split_recurrence_params
        raw = params[:recurrence]
        return {} unless raw

        if raw.respond_to?(:permit)
          raw = raw.permit(
            :ends_on, :local_start_time, :duration_minutes, :time_zone, :interval,
            weekdays: [],
            overrides: TrainingSeriesCreator::OVERRIDABLE_DEFAULTS
          )
        end
        raw.respond_to?(:to_h) ? raw.to_h : {}
      end

      def required_date_param(key)
        return required_date_error(key) if params[key].blank?

        Date.iso8601(params[key].to_s)
      rescue ArgumentError
        required_date_error(key)
      end

      def required_date_error(key)
        render json: { errors: [ "#{key} must be a valid date" ] },
               status: :unprocessable_entity
        nil
      end

      def boolean_param(key)
        ActiveModel::Type::Boolean.new.cast(params[key]) == true
      end

      # Audit trail for bulk/series decisions. LogService never raises, so a
      # logging failure cannot break the operation.
      def log_action(action, description, objects)
        LogService.log(
          description: description,
          action: action,
          method: request.request_method,
          path: request.path,
          request_id: request.request_id,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          status: response.status,
          user: Current.user,
          objects: Array(objects)
        )
      end

      def validate_index_filters!
        errors = []
        if params[:status].present? && !TrainingSeries::STATUSES.include?(params[:status])
          errors << "status is not included in the list"
        end

        @from = parse_date_param(:from, errors)
        @to = parse_date_param(:to, errors)

        render json: { errors: errors }, status: :unprocessable_entity if errors.any?
      end

      def validate_session_filters!
        errors = []
        if params[:status].present? && !TrainingSession::STATUSES.include?(params[:status])
          errors << "status is not included in the list"
        end

        @sessions_from = parse_time_param(:from, errors)
        @sessions_to = parse_time_param(:to, errors)

        render json: { errors: errors }, status: :unprocessable_entity if errors.any?
      end

      # The series list uses dates; the occurrence list uses timestamps. Both
      # accept an ISO string and share the same error shape.
      def parse_date_param(key, errors)
        return nil if params[key].blank?

        Date.iso8601(params[key].to_s)
      rescue ArgumentError
        errors << "#{key} is not a valid date"
        nil
      end

      def parse_time_param(key, errors)
        return nil if params[key].blank?

        Time.zone.parse(params[key].to_s).tap do |time|
          errors << "#{key} is not a valid time" if time.nil?
        end
      rescue ArgumentError
        errors << "#{key} is not a valid time"
        nil
      end
    end
  end
end
