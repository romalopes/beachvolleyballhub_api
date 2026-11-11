class Public::WeatherSharesController < ApplicationController
  # No authentication required - public access
  skip_before_action :require_authentication, raise: false
  skip_before_action :resume_session, raise: false

  # GET /weather/:public_token
  def show
    @snapshot = WeatherShareSnapshot.find_by(public_token: params[:public_token])

    unless @snapshot&.active?
      render :unavailable, status: :not_found, layout: false
      return
    end

    # Set cache headers - conservative to respect revocation/expiry
    response.headers["Cache-Control"] = "public, max-age=300, stale-while-revalidate=60"
    response.headers["Vary"] = "Accept"

    # Render the public page with OG metadata
    render :show, layout: false
  end

  private

  def snapshot_metadata
    {
      title: "Beach Volleyball Weather at #{@snapshot.location_name}",
      description: build_description,
      image: @snapshot.image_url,
      url: @snapshot.public_url,
      type: "website",
      site_name: "BeachVolleyballHub",
      twitter_card: "summary_large_image"
    }
  end

  def build_description
    parts = []
    parts << @snapshot.volleyball_label
    parts << "#{@snapshot.volleyball_score}/100" if @snapshot.volleyball_score
    parts << @snapshot.location_name
    parts.join(" · ")
  end

  helper_method :snapshot_metadata
end