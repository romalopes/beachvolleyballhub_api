module Api
  module V1
    # Reusable training definitions. Reading and writing both require a training
    # manager (coach/curator/admin), matching the existing rule for trainings:
    # management is role-based, never keyed on `created_by_id`.
    #
    # Templates are archived rather than destroyed; there is deliberately no
    # DELETE route so historical series/sessions cannot lose their definition.
    class TrainingTemplatesController < ApplicationController
      include ContentAuthorization
      include Pagination
      include RecurringTrainingAuthorization

      TEMPLATE_ATTRIBUTES = %i[
        id name description organisation_id group_id coach_profile_id location
        location_detail level capacity duration_minutes visibility status
        created_by_id created_at updated_at
      ].freeze

      before_action :require_training_manager!
      before_action :set_training_template, only: %i[show update archive restore clone]

      def index
        return render json: { errors: [ "status is not included in the list" ] },
                      status: :unprocessable_entity if invalid_status?

        records, meta = paginate(template_scope)

        render json: {
          data: records.map { |template| template_payload(template) },
          meta: meta
        }
      end

      def show
        render json: { training_template: template_payload(@training_template) }
      end

      def create
        template = TrainingTemplate.new(template_params.merge(created_by: Current.user))

        if template.save
          log_action("create", "Created training template \"#{template.name}\"", [ template ])
          render json: { training_template: template_payload(template) }, status: :created
        else
          render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @training_template.update(template_params)
          log_action("update", "Updated training template \"#{@training_template.name}\"",
                     [ @training_template ])
          render json: { training_template: template_payload(@training_template) }
        else
          render json: { errors: @training_template.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def archive
        @training_template.update!(status: "archived")
        log_action("archive", "Archived training template \"#{@training_template.name}\"",
                   [ @training_template ])
        render json: { training_template: template_payload(@training_template) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def restore
        @training_template.update!(status: "active")
        log_action("restore", "Restored training template \"#{@training_template.name}\"",
                   [ @training_template ])
        render json: { training_template: template_payload(@training_template) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # A copy is a new active template with the same defaults. Existing series
      # keep pointing at the original.
      def clone
        copy = @training_template.dup
        copy.name = "#{@training_template.name} (copy)"
        copy.status = "active"
        copy.created_by = Current.user

        if copy.save
          log_action("clone", "Cloned training template \"#{@training_template.name}\"",
                     [ copy ])
          render json: { training_template: template_payload(copy) }, status: :created
        else
          render json: { errors: copy.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def template_scope
        scope = TrainingTemplate
                  .includes(:organisation, :group, :coach_profile, :created_by)
                  .order(:name, :id)

        if params[:status].present?
          scope = scope.where(status: params[:status])
        elsif params[:include_archived].blank?
          scope = scope.where(status: "active")
        end

        scope = scope.where(organisation_id: params[:organisation_id]) if params[:organisation_id].present?
        scope = scope.where(group_id: params[:group_id]) if params[:group_id].present?
        scope = scope.where(coach_profile_id: params[:coach_profile_id]) if params[:coach_profile_id].present?

        if params[:q].present?
          term = "%#{params[:q]}%"
          scope = scope.where("training_templates.name ILIKE :term OR training_templates.description ILIKE :term",
                              term: term)
        end

        scope
      end

      def invalid_status?
        params[:status].present? && !TrainingTemplate::STATUSES.include?(params[:status])
      end

      def set_training_template
        @training_template = TrainingTemplate
                               .includes(:organisation, :group, :coach_profile, :created_by)
                               .find_by(id: params[:id])

        return if @training_template

        render json: { error: "Training template not found" }, status: :not_found
      end

      def template_params
        params.require(:training_template).permit(
          :name, :description, :organisation_id, :group_id, :coach_profile_id,
          :location, :location_detail, :level, :capacity, :duration_minutes,
          :visibility, :status
        )
      end

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

      def template_payload(template)
        template.as_json(
          only: TEMPLATE_ATTRIBUTES,
          methods: %i[location_summary],
          include: {
            organisation: { only: %i[id name] },
            group: { only: %i[id name] },
            coach_profile: { only: %i[id display_name] },
            created_by: { only: %i[id name] }
          }
        )
      end
    end
  end
end
