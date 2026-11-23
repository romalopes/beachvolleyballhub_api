require "test_helper"

# Resolving (or on-the-fly creating) the player profile behind a request
# submitter (IDENTITY-265).
class AnalysisRequests::SubmitterProfileTest < ActiveSupport::TestCase
  test "reuses the account's existing active profile" do
    result = AnalysisRequests::SubmitterProfile.for_user(users(:five))

    assert result.profile?
    assert_equal player_profiles(:john_player).id, result.profile.id
  end

  test "creates a profile for an account that has none" do
    user = users(:six)
    assert_empty user.account.player_profiles

    assert_difference "PlayerProfile.count", 1 do
      result = AnalysisRequests::SubmitterProfile.for_user(user)

      assert result.profile?
      assert_equal user.account.id, result.profile.account_id
      assert_equal user.email_address, result.profile.email
      assert result.profile.display_name.present?
    end

    # And the second call reuses what the first created.
    result = AnalysisRequests::SubmitterProfile.for_user(user)
    assert_equal user.account.player_profiles.active.sole.id, result.profile.id
  end

  test "resolves to no profile for guests and accountless users" do
    refute AnalysisRequests::SubmitterProfile.for_user(nil).profile?
    refute AnalysisRequests::SubmitterProfile.for_user(users(:one)).profile?
  end
end
