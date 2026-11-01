require "test_helper"

class AssessmentSessionPolicyTest < ActiveSupport::TestCase
  test "session managers can link an assessment session to an analysis" do
    session = assessment_sessions(:draft_squad)

    assert AssessmentSessionPolicy.new(users(:six), session).link_to_analysis?
    assert AssessmentSessionPolicy.new(users(:two), session).link_to_analysis?
    assert AssessmentSessionPolicy.new(users(:four), session).link_to_analysis?
    assert_not AssessmentSessionPolicy.new(users(:three), session).link_to_analysis?
    assert_not AssessmentSessionPolicy.new(nil, session).link_to_analysis?
  end
end
