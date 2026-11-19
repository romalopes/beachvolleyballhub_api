# frozen_string_literal: true
module Weather
  class DirectionPreferenceResolver
    def self.resolve(direction:, general:, beach: nil)
      AdvisorPreferences.direction_for(direction: direction, beach_preferences: beach, general_preferences: general)
    end

    def self.penalty(preference)
      AdvisorPreferences::DIRECTION_PENALTIES.fetch(preference.to_s, 0)
    end
  end
end