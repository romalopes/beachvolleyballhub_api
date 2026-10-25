class OrganisationLocation < ApplicationRecord
  belongs_to :organisation
  belongs_to :location

  validates :location_id, uniqueness: { scope: :organisation_id }
  validate :location_is_selectable

  private

  def location_is_selectable
    return if location&.selectable?

    errors.add(:location, "must be active and verified")
  end
end
