require "test_helper"

class AnalysisCommentPolicyTest < ActiveSupport::TestCase
  test "only the author or an administrator can destroy a comment" do
    comment = analysis_comments(:coach_led_comment_1)

    assert AnalysisCommentPolicy.new(users(:six), comment).destroy?
    assert AnalysisCommentPolicy.new(users(:two), comment).destroy?
    assert_not AnalysisCommentPolicy.new(users(:one), comment).destroy?
    assert_not AnalysisCommentPolicy.new(nil, comment).destroy?
  end
end
