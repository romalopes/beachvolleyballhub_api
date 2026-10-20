require "test_helper"

class ProfilePolicyTest < ActiveSupport::TestCase
  test "a regular Account can view and scope to linked profiles" do
    profile = player_profiles(:john_player)
    profile.update_columns(account_id: accounts(:one).id)
    actor = users(:five)
    policy = ProfilePolicy.new(actor: actor, profile: profile)

    assert policy.view?
    assert_not policy.update?
    assert_includes ProfilePolicy.scope(PlayerProfile.all, actor: actor), profile
    assert accounts(:two).coach?
    assert_not accounts(:one).coach?
  end

  test "a coach can change only profiles they created" do
    coach = users(:three)
    own = PlayerProfile.new(display_name: "Coach owned")
    ProfileOwnership.stamp!(own, coach)
    own.save!
    other = player_profiles(:john_player)
    policy = ProfilePolicy.new(actor: coach, profile: other)

    assert policy.view? # shared content remains visible to training managers
    assert_not policy.update?
    assert_not policy.invite?
    assert_not policy.review_claim?
    assert ProfilePolicy.new(actor: coach, profile: own).invite?
    assert ProfilePolicy.new(actor: coach, profile: own).review_claim?
    assert_not policy.destroy?
    assert ProfilePolicy.new(actor: coach, profile: own).update?
    assert ProfilePolicy.new(actor: coach, profile: own).destroy?
  end

  test "private profiles remain hidden from unrelated coaches" do
    private_profile = PlayerProfile.create!(
      display_name: "Policy Private",
      visibility: "private",
      created_by: users(:three),
      created_by_account: accounts(:three)
    )

    policy = ProfilePolicy.new(actor: users(:six), profile: private_profile)
    assert_not policy.view?
    assert_not policy.update?
    assert_not policy.invite?
  end

  test "administrators and curators retain their established oversight actions" do
    profile = player_profiles(:john_player)
    admin = ProfilePolicy.new(actor: users(:two), profile: profile)
    curator = ProfilePolicy.new(actor: users(:four), profile: profile)

    assert admin.view?
    assert admin.update?
    assert admin.invite?
    assert admin.review_claim?
    assert admin.merge?
    assert admin.destroy?
    assert curator.view?
    assert curator.update?
    assert curator.invite?
    assert curator.merge?
    assert curator.destroy?
  end

  test "both profile kinds allow their creator without requiring a coach role" do
    [PlayerProfile, CoachProfile].each do |klass|
      own = klass.new(display_name: "Creator profile", visibility: "private")
      ProfileOwnership.stamp!(own, users(:one))
      own.save!
      creator = ProfilePolicy.new(actor: users(:one), profile: own)
      assert creator.view?
      assert creator.update?
      assert creator.destroy?
      unrelated = ProfilePolicy.new(actor: users(:three), profile: own)
      assert_not unrelated.update?
      assert_not unrelated.destroy?
    end
  end

  test "creators and curators can delete unused profiles of either kind" do
    [PlayerProfile, CoachProfile].each do |klass|
      [users(:one), users(:four)].each do |actor|
        profile = klass.new(display_name: "Unused profile")
        ProfileOwnership.stamp!(profile, users(:one))
        profile.save!
        ProfileDeletionBlocker.destroy!(profile: profile, user: actor)
        assert_not klass.exists?(profile.id)
      end
    end
  end

  test "assessment history still blocks deletion for every permitted actor" do
    [player_profiles(:pedro_player), coach_profiles(:maria_coach)].each do |profile|
      profile.update_columns(created_by_id: users(:one).id, created_by_account_id: accounts(:one).id)
      [users(:one), users(:four), users(:two)].each do |actor|
        error = assert_raises(ProfileDeletionBlocker::Blocked) do
          ProfileDeletionBlocker.destroy!(profile: profile, user: actor)
        end
        assert_includes error.references, "assessments"
        assert profile.class.exists?(profile.id)
      end
    end
  end

  test "profile creation permissions distinguish player and coach profiles" do
    player = ProfilePolicy.new(actor: users(:one))
    coach = ProfilePolicy.new(actor: users(:three))
    curator = ProfilePolicy.new(actor: users(:four))
    unprivileged = ProfilePolicy.new(actor: users(:five))

    assert player.create_player?
    assert_not player.create_coach?
    assert coach.create_player?
    assert coach.create_coach?
    assert curator.create_player?
    assert curator.create_coach?
    assert_not unprivileged.create_player?
    assert_not unprivileged.create_coach?
  end
end
