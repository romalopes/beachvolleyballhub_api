module AnalysisRequests
  # Serialises the linked Analysis for the submitter-facing request pages
  # (IDENTITY-265).
  #
  # Two audiences, one shape: while the team is still working, only progress is
  # exposed; once the analysis is shared (published) or the request is completed,
  # the summary, videos and comments become readable. Internal tooling is never
  # included.
  class AnalysisPresenter
    STEP_LABELS = [
      [ "started", "Analysis started" ],
      [ "review", "Coach review" ],
      [ "shared", "Analysis shared" ],
      [ "completed", "Completed" ]
    ].freeze

    def initialize(request, blob_url: nil)
      @request = request
      @analysis = request.analysis
      @blob_url = blob_url
    end

    def as_json
      return nil unless @analysis

      {
        id: @analysis.id,
        title: @analysis.title,
        status: @analysis.status,
        available: available?,
        percent: percent,
        steps: steps,
        video_count: @analysis.analysis_videos.size,
        comment_count: @analysis.analysis_comments.size,
        summary: available? ? @analysis.summary : nil,
        videos: available? ? videos : [],
        comments: available? ? comments : []
      }
    end

    private

    def available?
      @analysis.published? || @analysis.archived? || completed?
    end

    def completed?
      @request.workflow_status == "completed"
    end

    def shared?
      @analysis.published? || @analysis.archived? || completed?
    end

    def percent
      done = steps.count { |step| step[:done] }
      ((done.to_f / steps.size) * 100).round
    end

    def steps
      STEP_LABELS.map do |key, label|
        done = case key
               when "started" then true
               when "review" then shared?
               when "shared" then shared?
               else completed?
               end
        current = case key
                  when "review" then !shared?
                  when "shared" then shared? && !completed?
                  else false
                  end

        { key: key, label: label, done: done, current: current }
      end
    end

    def videos
      @analysis.analysis_videos.map do |video|
        {
          id: video.id,
          title: video.title.presence || video.video&.title || video.file&.filename&.to_s,
          source_type: video.source_type,
          request_video_id: video.analysis_request_video_id,
          external_url: video.video&.external_url,
          embed_url: video.video&.embed_url,
          playback_url: playback_url(video)
        }
      end
    end

    def playback_url(video)
      return nil unless video.upload? && video.file.attached? && @blob_url

      @blob_url.call(video.file.blob)
    end

    def comments
      @analysis.analysis_comments.order(:created_at).map do |comment|
        {
          id: comment.id,
          body: comment.body,
          created_at: comment.created_at.iso8601,
          author: { id: comment.author_id, name: comment.author.name }
        }
      end
    end
  end
end
