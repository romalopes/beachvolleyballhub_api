module Billing
  # Human-readable identity for a billable owner, used only when creating a
  # Stripe Customer (IDENTITY-116).
  #
  # An organisation has no email of its own, so its billing email falls back to the
  # account that created it. A personal account uses its private contact email,
  # then its login address. Stripe accepts a customer without an email, so a
  # missing address is not a blocker.
  class OwnerContact
    class << self
      def email(owner)
        account = account_for(owner)
        account&.contact_detail&.email.presence || account&.user&.email_address.presence ||
          owner.try(:email).presence
      end

      def name(owner)
        case owner
        when Organisation
          owner.name.presence || "Organisation #{owner.id}"
        when Account
          owner.full_name.presence || email(owner) || "Account #{owner.id}"
        else
          owner.class.name
        end
      end

      private

      def account_for(owner)
        case owner
        when Account then owner
        when Organisation then owner.created_by_account
        end
      end
    end
  end
end
