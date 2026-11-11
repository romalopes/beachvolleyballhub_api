require "net/http"
require "json"

class WeatherShareImageGenerator
  RENDERER_URL = ENV.fetch("WEATHER_SHARE_RENDERER_URL", nil)
  STORAGE_SERVICE = ENV.fetch("WEATHER_SHARE_IMAGE_STORAGE_SERVICE", "cloudflare_r2")
  PUBLIC_IMAGE_HOST = ENV.fetch("WEATHER_SHARE_PUBLIC_IMAGE_HOST", nil)

  def self.generate_for(snapshot)
    new(snapshot).generate
  end

  def initialize(snapshot)
    @snapshot = snapshot
  end

  def generate
    return false unless @snapshot.active?
    return false unless RENDERER_URL.present?

    output_path = Rails.root.join("tmp", "weather-shares", "#{@snapshot.public_token}.png")
    FileUtils.mkdir_p(output_path.dirname)

    uri = URI("#{RENDERER_URL}/render")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 60
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = { snapshot: build_snapshot_payload, outputPath: output_path.to_s }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      upload_to_storage(output_path)
      true
    else
      Rails.logger.error("Image generation failed: #{response.body}")
      false
    end
  rescue => e
    Rails.logger.error("Image generation error: #{e.message}")
    false
  end

  private

  def build_snapshot_payload
    {
      location_name: @snapshot.location_name,
      forecast_target_time: @snapshot.forecast_target_time&.iso8601,
      timezone: @snapshot.timezone,
      current: @snapshot.weather_data["current"] || {},
      forecast: @snapshot.weather_data["forecast"] || [],
      volleyball: @snapshot.volleyball_assessment,
      public_url: @snapshot.public_url
    }
  end

  def upload_to_storage(local_path)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(local_path),
      filename: "#{@snapshot.public_token}.png",
      content_type: "image/png",
      service_name: STORAGE_SERVICE
    )
    @snapshot.update!(image_blob: blob)
  end

  def public_image_url
    return nil unless @snapshot.image_blob.present?

    if PUBLIC_IMAGE_HOST.present?
      "#{PUBLIC_IMAGE_HOST}/weather-shares/#{@snapshot.public_token}.png"
    else
      Rails.application.routes.url_helpers.rails_blob_url(
        @snapshot.image_blob,
        host: ENV.fetch("FRONTEND_URL", "http://localhost:5174")
      )
    end
  end
end