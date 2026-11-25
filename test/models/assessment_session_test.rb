require "test_helper"

class AssessmentSessionTest < ActiveSupport::TestCase
  setup do
    @active = assessment_definitions(:balanced)
    @draft = assessment_definitions(:pre_season)
    @coach = coach_profiles(:maria_coach)
  end

  test "a draft session needs only an active definition and a coach" do
    session = AssessmentSession.new(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "Tuesday squad screening",
      scheduled_on: Date.current
    )

    assert_predicate session, :valid?
    assert_predicate session, :draft?
  end

  test "a draft definition cannot back a session" do
    session = AssessmentSession.new(assessment_definition: @draft, coach_profile: @coach)

    assert_not session.valid?
    assert session.errors[:assessment_definition].any?
  end

  test "a coach is required" do
    session = AssessmentSession.new(assessment_definition: @active)

    assert_not session.valid?
    assert session.errors[:coach_profile].any?
  end

  test "status is constrained to the lifecycle" do
    session = AssessmentSession.new(
      assessment_definition: @active, coach_profile: @coach, status: "archived"
    )

    assert_not session.valid?
    assert session.errors[:status].any?
  end

  # A published session is archival. Without published_at it is not "published
  # yet", it is a row that lies about its own state, so the model refuses it
  # rather than letting the API hand out a session nobody can date.
  test "publishing requires a published_at timestamp" do
    session = AssessmentSession.new(
      assessment_definition: @active, coach_profile: @coach, status: "published"
    )

    assert_not session.valid?
    assert session.errors[:published_at].any?
  end

  test "the definition only has to be active when the session is created" do
    # Archiving a definition must not invalidate the sessions that already quote
    # it — otherwise retiring a template would silently orphan the history that
    # depends on it.
    session = assessment_sessions(:published_squad)
    @active.update!(status: "archived")

    assert session.valid?
  end

  test "included_participants separates expected players from absentees" do
    session = assessment_sessions(:draft_squad)

    ids = session.included_participants.pluck(:player_profile_id)
    assert_equal [ player_profiles(:john_player).id ], ids
    assert_equal 2, session.participants.count
  end

  test "destroying a session destroys its roster" do
    session = assessment_sessions(:draft_squad)
    participant_ids = session.participants.pluck(:id)

    session.destroy!

    assert_empty AssessmentSessionParticipant.where(id: participant_ids)
  end

  test "a session deletion never destroys the results that quote it" do
    session = assessment_sessions(:published_squad)
    player = player_profiles(:john_player)

    assessment = Assessment.new(
      player_profile: player,
      coach_profile: @coach,
      assessment_definition: @active,
      assessment_session: session,
      status: "draft"
    )
    @active.assessment_categories.ordered.each do |discipline|
      assessment.assessment_category_scores.build(
        assessment_category: discipline,
        scale: "one_to_ten",
        reported_value: 8,
        score: 80
      )
    end
    assessment.save!
    assessment.update!(status: "active")

    session.destroy!

    assert_nil assessment.reload.assessment_session_id, "the historical result must survive"
    assert_predicate assessment, :persisted?
  end

  # --- Visibility & Sharing ---

  test "visibility defaults to internal at model level" do
    session = AssessmentSession.new(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "New Session",
      scheduled_on: Date.current
    )
    assert_equal "internal", session.visibility
    assert_predicate session, :internal?
  end

  test "visibility is constrained to the allowed values" do
    session = AssessmentSession.new(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "New Session",
      scheduled_on: Date.current,
      visibility: "invalid"
    )

    assert_not session.valid?
    assert session.errors[:visibility].any?
  end

  test "each visibility value is accepted" do
    %w[public unlisted internal private].each do |value|
      session = AssessmentSession.new(
        assessment_definition: @active,
        coach_profile: @coach,
        name: "Session #{value}",
        scheduled_on: Date.current,
        visibility: value
      )
      assert_predicate session, :valid?, "visibility=#{value} should be valid"
    end
  end

  test "visibility predicate methods work" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "public")
    assert_predicate session, :public?
    assert_not session.unlisted?

    session.update!(visibility: "unlisted")
    assert_predicate session, :unlisted?
    assert_not session.internal?

    session.update!(visibility: "internal")
    assert_predicate session, :internal?
    assert_not session.private?

    session.update!(visibility: "private")
    assert_predicate session, :private?
    assert_not session.public?
  end

  test "public_slug is generated on create and is unique" do
    session = AssessmentSession.create!(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "Slug Test",
      scheduled_on: Date.current
    )
    assert_not_nil session.public_slug
    assert session.public_slug.start_with?("slug-test-")
    assert session.public_slug.length > 10
  end

  test "public_slug is stable when name changes" do
    session = AssessmentSession.create!(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "Original Name",
      scheduled_on: Date.current
    )
    original_slug = session.public_slug

    session.update!(name: "Completely Different Name")
    assert_equal original_slug, session.public_slug, "slug must not change when name changes"
  end

  test "public_slug uniqueness handles collisions" do
    session1 = AssessmentSession.create!(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "Same Name",
      scheduled_on: Date.current
    )
    session2 = AssessmentSession.create!(
      assessment_definition: @active,
      coach_profile: @coach,
      name: "Same Name",
      scheduled_on: Date.current
    )

    assert_not_equal session1.public_slug, session2.public_slug
    assert session1.public_slug.start_with?("same-name-")
    assert session2.public_slug.start_with?("same-name-")
  end

  test "regenerate_share_token! stores only SHA-256 digest and returns raw token once" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    raw_token = session.regenerate_share_token!
    session.save!

    # Raw token returned
    assert_not_nil raw_token
    assert_equal 32, raw_token.length # urlsafe_base64(24) = 32 chars

    # Only digest stored
    assert_not_equal raw_token, session.share_token_digest
    assert_equal Digest::SHA256.hexdigest(raw_token), session.share_token_digest

    # Validating the same token works
    assert session.valid_share_token?(raw_token)

    # Wrong token fails
    assert_not session.valid_share_token?("wrong-token")
  end

  test "regenerate_share_token! invalidates previous token" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    token1 = session.regenerate_share_token!
    session.save!

    token2 = session.regenerate_share_token!
    session.save!

    assert_not_equal token1, token2
    assert session.valid_share_token?(token2)
    assert_not session.valid_share_token?(token1), "old token must be invalidated"
  end

  test "clear_share_token! removes the digest" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    session.regenerate_share_token!
    session.save!

    session.clear_share_token!
    session.save!

    assert_nil session.share_token_digest
  end

  test "visibility change from unlisted to internal clears share token" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    session.regenerate_share_token!
    session.save!
    assert_not_nil session.share_token_digest

    session.update!(visibility: "internal")
    assert_nil session.share_token_digest, "leaving unlisted must clear share token"
  end

  test "visibility change from unlisted to public clears share token" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    session.regenerate_share_token!
    session.save!

    session.update!(visibility: "public")
    assert_nil session.share_token_digest
  end

  test "visibility change from unlisted to private clears share token" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    session.regenerate_share_token!
    session.save!

    session.update!(visibility: "private")
    assert_nil session.share_token_digest
  end

  test "visibility change between non-unlisted values does not error" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "public")
    session.update!(visibility: "internal")
    session.update!(visibility: "private")
    assert_predicate session, :persisted?
  end

  test "find_by_share_token! finds unlisted session by raw token" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    raw_token = session.regenerate_share_token!
    session.save!

    found = AssessmentSession.find_by_share_token!(raw_token)
    assert_equal session.id, found.id
  end

  test "find_by_share_token! raises for non-unlisted session" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "public")
    raw_token = session.regenerate_share_token!
    session.save!

    assert_raises(ActiveRecord::RecordNotFound) do
      AssessmentSession.find_by_share_token!(raw_token)
    end
  end

  test "find_by_share_token! raises for invalid token" do
    assert_raises(ActiveRecord::RecordNotFound) do
      AssessmentSession.find_by_share_token!("invalid-token")
    end
  end

  test "scopes filter by visibility correctly" do
    public_session = assessment_sessions(:published_squad)
    public_session.update!(visibility: "public")

    internal_session = assessment_sessions(:draft_squad)
    internal_session.update!(visibility: "internal")

    assert_includes AssessmentSession.visible_to_public, public_session
    assert_not_includes AssessmentSession.visible_to_public, internal_session

    assert_includes AssessmentSession.visible_to_internal, public_session
    assert_includes AssessmentSession.visible_to_internal, internal_session

    # unlisted scope should be chainable
    assert_kind_of ActiveRecord::Relation, AssessmentSession.unlisted
  end
end
