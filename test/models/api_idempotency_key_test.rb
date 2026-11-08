require "test_helper"

class ApiIdempotencyKeyTest < ActiveSupport::TestCase
  test "requires an actor, key, digest and status" do
    record = ApiIdempotencyKey.new

    assert_not record.valid?
    assert_includes record.errors.attribute_names, :actor_scope
    assert_includes record.errors.attribute_names, :request_key
    assert_includes record.errors.attribute_names, :request_digest
    assert_includes record.errors.attribute_names, :status
  end

  test "only replays when the request digest matches" do
    record = ApiIdempotencyKey.new(request_digest: "digest-a")

    assert record.replayable_for?("digest-a")
    assert_not record.replayable_for?("digest-b")
  end
end
