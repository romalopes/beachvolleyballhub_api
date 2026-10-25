# frozen_string_literal: true

module Geocoding
  Result = Data.define(
    :latitude,
    :longitude,
    :formatted_address,
    :locality,
    :administrative_area,
    :country_code,
    :provider,
    :provider_reference
  ) do
    def to_h
      self.class.members.to_h { |member| [ member, public_send(member) ] }
    end
  end
end
