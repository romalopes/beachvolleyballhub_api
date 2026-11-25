require "test_helper"

class AssessmentSessionPolicyTest < ActiveSupport::TestCase
  setup do
    @coach = coach_profiles(:maria_coach)          # account: two -> user: six
    @admin = users(:two)                            # admin + coach
    @curator = users(:four)                         # curator
    @player_user = users(:five)                     # player (account: one -> john_player)
    @other_coach_user = users(:three)               # coach with account three
    @other_coach = coach_profiles(:unclaimed_roster_coach) # no account
    @outsider = users(:one)                         # has player role in fixtures
    @session = assessment_sessions(:draft_squad)    # coach: maria_coach (six)
    @coach_user = @coach.account&.user              # the user behind the coach profile

    # Ensure player_user has the player role (fixtures don't assign it to users(:five))
    UserRole.find_or_create_by!(user: @player_user, role: roles(:player))

    # Remove player role from outsider for tests that need a non-player non-manager
    @outsider.user_roles.destroy_all
  end

  def policy_for(user, record = @session)
    AssessmentSessionPolicy.new(user, record)
  end

  def scope_for(user)
    AssessmentSessionPolicy::Scope.new(user, AssessmentSession.all).resolve
  end

  # --- show? ---

  test "show? returns false for anonymous" do
    assert_not policy_for(nil).show?
  end

  test "show? returns true for public session with authenticated user" do
    @session.update!(visibility: "public")
    assert policy_for(@player_user).show?
    assert policy_for(@other_coach_user).show?
  end

  test "show? returns false for unlisted session via standard auth" do
    @session.update!(visibility: "unlisted")
    assert_not policy_for(@player_user).show?
    assert_not policy_for(@other_coach_user).show?
  end

  test "show? returns true for internal session when user is involved player" do
    @session.update!(visibility: "internal")
    @session.reload
    assert policy_for(@player_user).show?
  end

  test "show? returns false for internal session when player is uninvolved" do
    @session.update!(visibility: "internal")
    @session.reload
    other_user = @outsider
    assert_not policy_for(other_user).show?
  end

  test "show? returns false for private session for non-management user" do
    @session.update!(visibility: "private")
    assert_not policy_for(@player_user).show?
    assert_not policy_for(@other_coach_user).show?
  end

  test "show? returns true for private session for coach of record" do
    @session.update!(visibility: "private")
    assert policy_for(@coach_user).show?
  end

  test "show? returns true for private session for admin" do
    @session.update!(visibility: "private")
    assert policy_for(@admin).show?
  end

  test "show? returns true for private session for curator (oversight)" do
    @session.update!(visibility: "private")
    assert policy_for(@curator).show?
  end

  # --- management_authority? actions (update?, destroy?, add_players?, remove_players?, scores?, publish?, withdraw?) ---

  test "management actions allowed for coach of record" do
    %i[update? destroy? add_players? remove_players? scores? publish? withdraw?].each do |action|
      assert policy_for(@coach_user).send(action), "coach of record should be allowed #{action}"
    end
  end

  test "management actions allowed for admin" do
    %i[update? destroy? add_players? remove_players? scores? publish? withdraw?].each do |action|
      assert policy_for(@admin).send(action), "admin should be allowed #{action}"
    end
  end

  test "management actions allowed for curator (oversight)" do
    %i[update? destroy? add_players? remove_players? scores? publish? withdraw?].each do |action|
      assert policy_for(@curator).send(action), "curator should be allowed #{action}"
    end
  end

  test "management actions denied for unassigned coach" do
    %i[update? destroy? add_players? remove_players? scores? publish? withdraw?].each do |action|
      assert_not policy_for(@other_coach_user).send(action), "unassigned coach should be denied #{action}"
    end
  end

  test "management actions denied for involved player" do
    %i[update? destroy? add_players? remove_players? scores? publish? withdraw?].each do |action|
      assert_not policy_for(@player_user).send(action), "player should be denied #{action}"
    end
  end

  test "destroy? returns false for published session even for coach of record" do
    @session.update!(status: "published", published_at: Time.current)
    assert_not policy_for(@coach_user).destroy?
  end

  test "restore? only for admin" do
    assert policy_for(@admin).restore?
    assert_not policy_for(@coach_user).restore?
    assert_not policy_for(@curator).restore?
    assert_not policy_for(@player_user).restore?
  end

  # --- manage_visibility? ---

  test "manage_visibility? allowed for coach of record, admin, curator" do
    assert policy_for(@coach_user).manage_visibility?
    assert policy_for(@admin).manage_visibility?
    assert policy_for(@curator).manage_visibility?
  end

  test "manage_visibility? denied for others" do
    assert_not policy_for(@other_coach_user).manage_visibility?
    assert_not policy_for(@player_user).manage_visibility?
  end

  # --- regenerate_share_link? ---

  test "regenerate_share_link? allowed for management authority on unlisted session" do
    @session.update!(visibility: "unlisted")
    assert policy_for(@coach_user).regenerate_share_link?
    assert policy_for(@admin).regenerate_share_link?
    assert policy_for(@curator).regenerate_share_link?
  end

  test "regenerate_share_link? denied for non-unlisted session" do
    @session.update!(visibility: "public")
    assert_not policy_for(@coach_user).regenerate_share_link?
    @session.update!(visibility: "internal")
    assert_not policy_for(@coach_user).regenerate_share_link?
  end

  # --- Scope ---

  test "Scope returns all sessions for content_manager (coach, curator, admin)" do
    sessions = scope_for(@coach_user)
    assert_includes sessions, @session
    assert_includes sessions, assessment_sessions(:published_squad)
  end

  test "Scope returns all sessions for admin" do
    sessions = scope_for(@admin)
    assert_includes sessions, @session
  end

  test "Scope returns all sessions for curator" do
    sessions = scope_for(@curator)
    assert_includes sessions, @session
  end

  test "Scope returns involved sessions + public sessions for player" do
    public_session = assessment_sessions(:published_squad)
    public_session.update!(visibility: "public")

    @session.update!(visibility: "internal")
    @session.reload

    sessions = scope_for(@player_user)
    assert_includes sessions, @session
    assert_includes sessions, public_session
  end

  test "Scope does not return private sessions for player" do
    @session.update!(visibility: "private")
    sessions = scope_for(@player_user)
    assert_not_includes sessions, @session
  end

  test "Scope does not return unlisted sessions for player" do
    @session.update!(visibility: "unlisted")
    sessions = scope_for(@player_user)
    assert_not_includes sessions, @session
  end

  test "Scope returns only public sessions for non-player non-manager" do
    outsider = @outsider
    public_session = assessment_sessions(:published_squad)
    public_session.update!(visibility: "public")
    @session.update!(visibility: "internal")

    sessions = scope_for(outsider)
    assert_includes sessions, public_session
    assert_not_includes sessions, @session
  end

  # --- link_to_analysis? (existing test) ---

  test "session managers can link an assessment session to an analysis" do
    session = assessment_sessions(:draft_squad)

    assert AssessmentSessionPolicy.new(users(:six), session).link_to_analysis?
    assert AssessmentSessionPolicy.new(users(:two), session).link_to_analysis?
    assert AssessmentSessionPolicy.new(users(:four), session).link_to_analysis?
    assert_not AssessmentSessionPolicy.new(users(:three), session).link_to_analysis?
    assert_not AssessmentSessionPolicy.new(nil, session).link_to_analysis?
  end
end
