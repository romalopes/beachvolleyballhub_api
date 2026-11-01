class ApplicationController < ActionController::Base
  include Authentication
  include Impersonation
  # Pundit: policy objects + policy_scope enforce authorization for every
  # controller. `authorize`/`policy_scope` are available app-wide.
  include Pundit::Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Skip CSRF for API requests (JSON)
  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  # Any unhandled Pundit denial is rendered through the app-wide contract:
  # 401 when unauthenticated, 404 for hidden records on read queries (so their
  # existence is not disclosed), 403 otherwise. HTML clients get a redirect.
  rescue_from Pundit::NotAuthorizedError, with: :handle_pundit_unauthorized

  before_action :set_sentry_context

  private

  # The policy "user" is the EFFECTIVE user (impersonated user while an admin is
  # impersonating), matching the historical `Current.user` semantics. Policies
  # that need the real authenticated user call `real_admin?` / `real_user`.
  def pundit_user
    Current.user
  end

  def handle_pundit_unauthorized(exception)
    # Read queries on a record the actor may not see must not reveal existence:
    # render 404 regardless of whether the caller is authenticated. This keeps
    # the historical "hidden record looks like a missing record" behaviour.
    if exception.query.to_s == "show?"
      return render_not_found_response
    end

    # Everything else follows the app-wide contract: 401 when unauthenticated,
    # 403 when authenticated but forbidden.
    render_unauthorized_or_forbidden
  end

  def render_not_found_response
    if request.format.json?
      render json: { error: "Not found" }, status: :not_found
    elsif lookup_context.exists?("shared/not_found")
      render "shared/not_found", status: :not_found
    else
      head :not_found
    end
  end


  # Authorization helpers
  #
  # Admin checks use the REAL authenticated user so an admin who is
  # impersonating a normal user never loses access to admin functionality.
  # Content/ownership checks intentionally use the EFFECTIVE user
  # (Current.user), so operations performed while impersonating act as the
  # impersonated user.
  #
  # `authorize_admin!` is now a thin Pundit wrapper (AdminAreaPolicy#access?,
  # which uses real_admin?). Kept as a method so existing admin controllers
  # need no change while the rest of the system migrates to `authorize`.
  def authorize_admin!
    authorize :admin_area, :access?
  end

  def authorize_owner_or_admin!(owner)
    return if Current.user&.admin? || Current.user == owner

    render_unauthorized_or_forbidden
  end

  # JSON clients (the React SPA) get a 401 instead of an HTML login redirect.
  def request_authentication
    if request.format.json?
      head :unauthorized
    else
      super
    end
  end

  private

  def render_unauthorized_or_forbidden
    if Current.user.nil?
      if request.format.json?
        head :unauthorized
      else
        redirect_to new_session_path, alert: "Please sign in."
      end
    elsif request.format.json?
      render json: { error: "Forbidden" }, status: :forbidden
    else
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
  end

  def set_sentry_context
    if current_user.present?
      Sentry.set_user(id: current_user.id)
      tier = current_user.try(:account_tier) || current_user.try(:tier) || 'unknown'
      Sentry.set_tags(user_id: current_user.id, account_tier: tier)
    else
      # sentry-ruby 7.x requires a Hash for set_user/set_tags; passing nil
      # raises ArgumentError. Clear any stale context with empty hashes.
      Sentry.set_user({})
      Sentry.set_tags({})
    end
  end
end