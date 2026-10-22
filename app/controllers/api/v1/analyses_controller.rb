module Api
  module V1
    class AnalysesController < ApplicationController
      include Pagination
      before_action :require_authentication
      before_action :require_manager!, only: :create
      before_action :set_analysis, except: %i[index create]
      before_action :authorize_view!, only: :show
      before_action :authorize_manage!, only: %i[update publish archive link_assessment_session unlink_assessment_session destroy]

      def index
        rows = AnalysisPolicy.scope(Current.user)
                           .includes(:created_by, :assigned_coach_profile, :organisation, :group, :training_session, :tournament,
                                     analysis_participants: :player_profile)
                           .ordered
        rows = rows.where(status: params[:status]) if Analysis::STATUSES.include?(params[:status])
        rows = rows.where(organisation_id: params[:organisation_id]) if params[:organisation_id].present?
        rows = rows.where(group_id: params[:group_id]) if params[:group_id].present?
        rows = rows.where("analyses.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%") if params[:q].present?
        records, meta = paginate(rows)
        render json: { data: records.map { |row| serialize(row, detail: false) }, meta: meta }
      end

      def show
        render json: { analysis: serialize(@analysis, detail: true) }
      end

      def create
        analysis = Analysis.new(analysis_params.except(:player_profile_ids))
        analysis.created_by = Current.user
        sync_participants(analysis, analysis_params[:player_profile_ids])
        if analysis.save
          render json: { analysis: serialize(analysis.reload, detail: true) }, status: :created
        else
          render json: { errors: analysis.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        attrs = analysis_params
        sync_participants(@analysis, attrs.delete(:player_profile_ids)) if attrs.key?(:player_profile_ids)
        if @analysis.update(attrs)
          render json: { analysis: serialize(@analysis.reload, detail: true) }
        else
          render json: { errors: @analysis.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def publish
        if @analysis.analysis_videos.none? || @analysis.analysis_participants.none?
          return render json: { errors: ["Add at least one video and one participant before publishing"] }, status: :unprocessable_entity
        end
        @analysis.publish!
        render json: { analysis: serialize(@analysis.reload, detail: true) }
      end

      def archive
        @analysis.archive!
        render json: { analysis: serialize(@analysis.reload, detail: true) }
      end

      def destroy
        unless AnalysisPolicy.new(actor: Current.user, analysis: @analysis).destroy?
          return render_unauthorized_or_forbidden
        end
        @analysis.destroy!
        head :no_content
      end

      def link_assessment_session
        session_record = AssessmentSession.find(params.require(:assessment_session_id))
        unless assessment_session_manageable?(session_record)
          return render json: { error: "Forbidden" }, status: :forbidden
        end
        @analysis.analysis_assessment_sessions.find_or_create_by!(assessment_session: session_record)
        render json: { analysis: serialize(@analysis.reload, detail: true) }
      end

      def unlink_assessment_session
        @analysis.analysis_assessment_sessions.where(assessment_session_id: params[:assessment_session_id]).destroy_all
        render json: { analysis: serialize(@analysis.reload, detail: true) }
      end

      private

      def require_manager!
        return if Current.user&.content_manager?
        render_unauthorized_or_forbidden
      end

      def set_analysis
        @analysis = Analysis.includes(:created_by, :assigned_coach_profile, :organisation, :group, :training_session, :tournament,
                                      analysis_participants: :player_profile,
                                      analysis_videos: [:video, :file_attachment, { analysis_annotations: [:author, :player_profile] }],
                                      analysis_comments: [:author, :parent], assessment_sessions: [:assessment_definition, :coach_profile])
                            .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis not found" }, status: :not_found
      end

      def authorize_view!
        render json: { error: "Analysis not found" }, status: :not_found unless AnalysisPolicy.new(actor: Current.user, analysis: @analysis).view?
      end

      def authorize_manage!
        render_unauthorized_or_forbidden unless AnalysisPolicy.new(actor: Current.user, analysis: @analysis).manage?
      end

      def analysis_params
        params.require(:analysis).permit(:title, :summary, :assigned_coach_profile_id, :organisation_id, :group_id, :training_session_id, :tournament_id, player_profile_ids: [])
      end

      def sync_participants(analysis, ids)
        return if ids.nil?
        analysis.analysis_participants = PlayerProfile.active.where(id: Array(ids).map(&:to_i).uniq).map { |profile| AnalysisParticipant.new(player_profile: profile) }
      end

      def assessment_session_manageable?(record)
        user = Current.user
        user&.admin? || user&.curator? || record.created_by_id == user&.id || record.coach_profile&.account_id == user&.account&.id
      end

      def serialize(row, detail:)
        policy = AnalysisPolicy.new(actor: Current.user, analysis: row)
        payload = { id: row.id, title: row.title, summary: row.summary, status: row.status,
          published_at: row.published_at, archived_at: row.archived_at, created_at: row.created_at, updated_at: row.updated_at,
          can_manage: policy.manage?, can_delete: policy.destroy?, can_comment: policy.comment?,
          created_by: { id: row.created_by_id, name: row.created_by.name },
          assigned_coach_profile: row.assigned_coach_profile && { id: row.assigned_coach_profile_id, name: row.assigned_coach_profile.full_name },
          organisation: row.organisation && { id: row.organisation_id, name: row.organisation.name },
          group: row.group && { id: row.group_id, name: row.group.name },
          training_session: row.training_session && { id: row.training_session_id, title: row.training_session.title },
          tournament: row.tournament && { id: row.tournament_id, name: row.tournament.name },
          participants: row.analysis_participants.map { |p| { id: p.id, player_profile_id: p.player_profile_id, name: p.player_profile.full_name, notes: p.notes } },
          video_count: row.analysis_videos.size }
        return payload unless detail
        payload.merge(videos: row.analysis_videos.map { |video| serialize_video(video) },
                      comments: row.analysis_comments.map { |comment| serialize_comment(comment) },
                      assessment_sessions: row.assessment_sessions.map { |s| { id: s.id, name: s.name, status: s.status, scheduled_on: s.scheduled_on, assessment_definition: { id: s.assessment_definition_id, name: s.assessment_definition.name } } })
      end

      def serialize_video(record)
        { id: record.id, source_type: record.source_type, title: record.title.presence || record.video&.title || record.file&.filename&.to_s,
          description: record.description, position: record.position,
          playback_url: record.upload? && record.file.attached? ? rails_blob_path(record.file, disposition: "inline", only_path: true) : record.video&.embed_url,
          external_url: record.video&.external_url, can_embed: record.external? && record.video&.can_embed?,
          duration_seconds: record.video&.duration_seconds,
          annotations: record.analysis_annotations.map { |a| { id: a.id, timestamp_seconds: a.timestamp_seconds, body: a.body,
            author: { id: a.author_id, name: a.author.name },
            player_profile: a.player_profile && { id: a.player_profile_id, name: a.player_profile.full_name }, created_at: a.created_at } } }
      end

      def serialize_comment(comment)
        { id: comment.id, body: comment.body, parent_id: comment.parent_id, author: { id: comment.author_id, name: comment.author.name },
          created_at: comment.created_at, can_delete: Current.user&.admin? || comment.author_id == Current.user&.id }
      end
    end
  end
end