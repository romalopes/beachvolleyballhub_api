module ProfileCreationMemberships
  private

  # A profile creator may attach the profile to an organisation they actively
  # belong to. This is deliberately narrower than the organisation roster API:
  # creating one's own record is not a general grant to manage somebody else's.
  # Admins retain site-wide oversight. A selected group must belong to the same
  # organisation; creating the organisation row first also satisfies Group's
  # roster-invariant validation before its membership is saved.
  def create_profile_memberships!(profile:, attributes:)
    selection = attributes.to_h.with_indifferent_access
    organisation_id = selection[:organisation_id].presence
    group_id = selection[:group_id].presence

    return true if organisation_id.blank? && group_id.blank?
    return membership_creation_error!("Choose an organisation before choosing a group.") if organisation_id.blank?

    organisation = Organisation.find_by(id: organisation_id)
    return membership_creation_error!("Organisation not found.", :not_found) unless organisation
    return membership_creation_error!("You must be an active member of this organisation to attach a new profile.", :forbidden) unless allowed_profile_creation_organisation?(organisation)

    group = group_id.present? && Group.find_by(id: group_id)
    return membership_creation_error!("Group not found.", :not_found) if group_id.present? && group.nil?
    return membership_creation_error!("The selected group does not belong to the selected organisation.") if group && group.organisation_id != organisation.id

    OrganisationMembership.create!(organisation: organisation, memberable: profile, role: "member", status: "active")
    GroupMembership.create!(group: group, memberable: profile, role: "member", status: "active") if group
    true
  end

  def allowed_profile_creation_organisation?(organisation)
    Current.user&.admin? || organisation.organisation_memberships
                                         .for_user_subjects(Current.user)
                                         .active
                                         .exists?
  end

  def membership_creation_error!(message, status = :unprocessable_entity)
    render json: { errors: [ message ] }, status: status
    false
  end
end