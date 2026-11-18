require "test_helper"

# Authorization rules for the internal Contact Messages inbox (IDENTITY-259).
#
# Pinned here: the inbox is platform-staff only. A coach or player is denied even
# though coaches manage much of the catalogue, and organisation-level roles are a
# separate concept that cannot grant access.
class ContactMessagePolicyTest < ActiveSupport::TestCase
  setup do
    @message = contact_messages(:unread_general)
  end

  test "platform admins may list, read and update messages" do
    policy = ContactMessagePolicy.new(users(:two), @message)

    assert policy.index?
    assert policy.show?
    assert policy.update?
  end

  test "platform curators may list, read and update messages" do
    policy = ContactMessagePolicy.new(users(:four), @message)

    assert policy.index?
    assert policy.show?
    assert policy.update?
  end

  test "coaches, players and anonymous visitors are denied" do
    [ users(:three), users(:one), nil ].each do |user|
      policy = ContactMessagePolicy.new(user, @message)

      assert_not policy.index?
      assert_not policy.show?
      assert_not policy.update?
      assert_not policy.destroy?
    end
  end

  test "the scope returns every message to staff and none to anybody else" do
    assert_equal ContactMessage.count,
                 ContactMessagePolicy::Scope.new(users(:two), ContactMessage).resolve.count
    assert_equal ContactMessage.count,
                 ContactMessagePolicy::Scope.new(users(:four), ContactMessage).resolve.count

    assert_equal 0, ContactMessagePolicy::Scope.new(users(:three), ContactMessage).resolve.count
    assert_equal 0, ContactMessagePolicy::Scope.new(users(:one), ContactMessage).resolve.count
    assert_equal 0, ContactMessagePolicy::Scope.new(nil, ContactMessage).resolve.count
  end
end
