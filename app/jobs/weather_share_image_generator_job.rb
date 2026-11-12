class WeatherShareImageGeneratorJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(snapshot)
    return unless snapshot&.active?

    WeatherShareImageGenerator.generate_for(snapshot)
  end
end
