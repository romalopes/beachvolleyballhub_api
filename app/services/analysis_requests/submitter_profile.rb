# frozen_string_literal: true

module AnalysisRequests
  # Resolves the player profile a hired analysis belongs to (IDENTITY-265).
  #
  # A signed-in submitter may or may not have a PlayerProfile yet — an account
  # is created at registration, but the player profile only exists once someone
  # recorded (or claimed) a catalogue row. For hiring an analysis the profile
  # must exist, because the produced Analysis lists the submitter as a
  # participant; so the first request creates it on the fly, and every later
  # request reuses it. Guests (no account) resolve to nil — they stay
  # identified by their guest contact fields.
  class SubmitterProfile
    Result = Data.define(:profile) do
      def profile? = !profile.nil?
    end

    class << self
      def for_user(user)
        return Result.new(profile: nil) if user.nil? || user.account.nil?

        profile = user.account.player_profiles.active.order(:id).first
        profile ||= create_profile_for(user)
        Result.new(profile: profile)
      end

      private

      def create_profile_for(user)
        PlayerProfile.create!(
          account: user.account,
          created_by: user,
          created_by_account: user.account,
          # display_name is derived from the account's contact details when they
          # exist; accounts without them (legacy/fixture data) fall back to the
          # user's display label. status/visibility have schema defaults.
          display_name: user.account.full_name.presence || user.name,
          email: user.email_address
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
        # A missing/malformed account must never block the submission itself;
        # the request simply stays without a player profile.
        nil
      end
    end
  end
end
