class LocationDefaultResolver
  class << self
    def for_event(group_id: nil, organisation_id: nil)
      group = Group.includes(:default_location, organisation: :default_location).find_by(id: group_id)
      group&.default_location || group&.organisation&.default_location ||
        Organisation.includes(:default_location).find_by(id: organisation_id)&.default_location
    end
  end
end
