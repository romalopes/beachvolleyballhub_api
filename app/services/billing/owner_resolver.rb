module Billing
  # Resolves the billable owner from authenticated server-side context
  # (IDENTITY-116, Phase 4).
  #
  # Two rules make IDOR impossible here:
  #   1. the caller never supplies the owner *record* — only a type and an id;
  #   2. an organisation id is only accepted when the caller is an active
  #      owner/administrator of that exact organisation (site admins excepted, and
  #      their actions are audited separately).
  #
  # A personal subscription always belongs to `Current.user.account`, so a user can
  # never buy or inspect a plan on somebody else's personal account.
  class OwnerResolver
    PERSONAL_TYPES = %w[personal account].freeze
    ORGANISATION_TYPES = %w[organisation club].freeze

    def initialize(user)
      @user = user
    end

    attr_reader :user

    def personal
      account = user&.account
      raise Errors::OwnerNotEligible, "Sign in with a complete account to manage billing" unless account

      account
    end

    def resolve(owner_type: nil, owner_id: nil)
      type = owner_type.to_s.strip.downcase
      return personal if type.blank? || PERSONAL_TYPES.include?(type)
      raise Errors::OwnerNotEligible unless ORGANISATION_TYPES.include?(type)

      organisation(owner_id)
    end

    def organisation(owner_id)
      raise Errors::OwnerNotEligible, "An organisation id is required" if owner_id.blank?

      organisation = Organisation.find_by(id: owner_id)
      raise Errors::OwnerNotEligible unless organisation
      raise Errors::OwnerNotEligible unless can_manage?(organisation)

      organisation
    end

    # Who may start Checkout, open the Customer Portal, or request a plan change.
    # Owners and administrators of the club, plus a site admin acting in support.
    def can_manage?(owner)
      return false if owner.blank?
      return true if user&.admin? || user&.curator?

      case owner
      when Account
        owner.id == user&.account&.id
      when Organisation
        OrganisationAccess.manages_membership?(owner, user&.account)
      else
        false
      end
    end
  end
end
