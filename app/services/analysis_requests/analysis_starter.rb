module AnalysisRequests
  # Starts production for an approved analysis request (IDENTITY-265).
  #
  # The request can only be worked on once the team has approved it, and the
  # work happens in a real Analysis record so the existing analysis editor,
  # comments, annotations and assessment tooling can be used. The request keeps
  # pointing at that Analysis so the submitter can follow progress.
  class AnalysisStarter
    class NotApproved < StandardError; end
    class AlreadyStarted < StandardError; end

    # "Approved" means accepted or anything after it; a quoted (not yet
    # accepted) request has no agreed price/scope to work from.
    APPROVED_STATUSES = %w[accepted awaiting_payment in_progress].freeze

    def initialize(request:, actor:)
      @request = request
      @actor = actor
    end

    def call
      raise AlreadyStarted if request.analysis_id.present?

      unless APPROVED_STATUSES.include?(request.workflow_status)
        raise NotApproved, "Approve the request before starting the analysis"
      end

      analysis = nil
      Analysis.transaction do
        analysis = create_analysis
        copy_videos(analysis)
        request.update!(
          analysis: analysis,
          workflow_status: "in_progress",
          work_started_at: request.work_started_at || Time.current
        )
      end

      Notifications::WorkflowEvents.analysis_request_work_started(request)
      analysis
    end

    private

    attr_reader :request, :actor

    def create_analysis
      Analysis.create!(
        title: request.title.truncate(160),
        summary: request.description,
        status: "draft",
        created_by: actor,
        assigned_coach_profile: request.assigned_coach_profile
      )
    end

    # Copies what the Analysis domain can represent: a catalogue video, an
    # uploaded file (the blob is shared, not duplicated), or an external URL that
    # resolves to a known provider. Anything else stays on the request (the
    # team can still see it there).
    def copy_videos(analysis)
      request.analysis_request_videos.order(:position).each do |source|
        if source.video_id.present?
          analysis.analysis_videos.create!(
            source_type: "external",
            video_id: source.video_id,
            position: source.position,
            title: source.video&.title,
            analysis_request_video: source
          )
        elsif source.file.attached?
          copy_upload(analysis, source)
        elsif source.external_url.present?
          copy_external_url(analysis, source)
        end
      end
    end

    def copy_upload(analysis, source)
      video = analysis.analysis_videos.new(
        source_type: "upload",
        position: source.position,
        title: source.file.filename.to_s,
        analysis_request_video: source
      )
      video.file.attach(source.file.blob)
      video.save!
    end

    def copy_external_url(analysis, source)
      video = Video.find_or_create_from_url!(
        source.external_url,
        created_by: actor
      )
      return if video.nil?

      analysis.analysis_videos.create!(
        source_type: "external",
        video_id: video.id,
        position: source.position,
        title: video.title,
        analysis_request_video: source
      )
    end
  end
end
