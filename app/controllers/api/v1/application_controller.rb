module Api
  module V1
    # Base controller for the JSON API. All Api::V1::*Controller classes that
    # declare `ApplicationController` resolve to this class via constant lookup.
    class ApplicationController < ::ApplicationController
      # JSON API consumers (the React SPA) authenticate with cookie sessions but
      # do not carry CSRF tokens; null_session would drop cookies on unverified
      # POSTs. JSON POSTs are protected cross-origin by CORS anyway.
      skip_forgery_protection

      # Public API — no User authentication required to browse data.
      skip_before_action :require_authentication, raise: false

      # Private test-access gate: while TEST_ACCESS_PASSWORD is configured,
      # every API request must carry a valid signed test-access token (see
      # TestAccess / TestAccessToken). Independent of User authentication.
      include TestAccess

      around_action :with_idempotency_key

      # Always populate Current.session from the cookie so authorization helpers
      # (admin?/coach?/owner checks) work even when authentication is optional.
      before_action :resume_session

      private

      def with_idempotency_key
        key = request.headers["X-Idempotency-Key"].to_s.strip
        return yield if key.blank? || !%w[POST PUT PATCH DELETE].include?(request.request_method)

        actor_scope = Current.user ? "user:#{Current.user.id}" : "anonymous"
        digest = Digest::SHA256.hexdigest(request.raw_post.to_s)
        stored = ApiIdempotencyKey.find_by(actor_scope: actor_scope, request_key: key)

        if stored
          return replay_idempotency_response(stored) if stored.replayable_for?(digest)

          return render json: {
            error: "Idempotency key was already used with a different request payload"
          }, status: :conflict
        end

        yield
        return unless response.successful?

        ApiIdempotencyKey.create!(
          actor_scope: actor_scope,
          request_key: key,
          request_method: request.request_method,
          request_path: request.path,
          request_digest: digest,
          status: response.status,
          content_type: response.media_type || "application/json",
          response_body: response.body.to_s
        )
      rescue ActiveRecord::RecordNotUnique
        stored = ApiIdempotencyKey.find_by!(actor_scope: actor_scope, request_key: key)
        return replay_idempotency_response(stored) if stored.replayable_for?(digest)

        render json: { error: "Idempotency key was already used with a different request payload" },
               status: :conflict
      end

      def replay_idempotency_response(stored)
        self.response_body = stored.response_body
        response.status = stored.status
        response.content_type = stored.content_type
      end
    end
  end
end
