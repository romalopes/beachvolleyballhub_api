require "test_helper"

class LoginDetailsCollectorTest < ActiveSupport::TestCase
  setup do
    # No geolocation key in tests -> Location stays "Unknown", no network call.
    ENV["IP2LOCATION_API_KEY"] = nil

    @request = ActionDispatch::TestRequest.create
    @request.remote_addr = "203.0.113.10"
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "\
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/605.1.15"
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "derives browser, os and device from a real Chrome UA" do
    details = LoginDetailsCollector.collect(@request, login_method: "password")

    assert_equal "203.0.113.10", details.ip_address
    assert_equal "password", details.login_method
    assert_equal "Chrome", details.browser
    refute_equal LoginDetails::UNKNOWN, details.browser_version
    assert_equal "OS X 10.15.7", details.os
    assert_equal "Desktop", details.device
    refute details.mobile
  end

  test "iPhone UA yields Safari / iOS / iPhone and mobile=true" do
    @request.user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "\
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    details = LoginDetailsCollector.collect(@request)

    assert_equal "Safari", details.browser
    assert_equal "iOS 17.0", details.os
    assert_equal "iPhone", details.device
    assert details.mobile
  end

  test "blank UA degrades all parsed fields to Unknown" do
    @request.user_agent = nil

    details = LoginDetailsCollector.collect(@request)

    assert_equal LoginDetails::UNKNOWN, details.browser
    assert_equal LoginDetails::UNKNOWN, details.browser_version
    assert_equal LoginDetails::UNKNOWN, details.os
    assert_equal LoginDetails::UNKNOWN, details.device
    assert_equal LoginDetails::UNKNOWN, details.location
    assert_equal LoginDetails::UNKNOWN, details.user_agent
    refute details.mobile
  end

  test "serializable_hash is plain-JSON and round-trips through ActiveJob arguments" do
    details = LoginDetailsCollector.collect(@request, login_method: "password")
    hash = details.serializable_hash

    assert_nothing_raised do
      ActiveJob::Arguments.serialize([1, hash])
    end

    assert hash["browser"] == "Chrome"
    assert hash["device"] == "Desktop"
  end
end
