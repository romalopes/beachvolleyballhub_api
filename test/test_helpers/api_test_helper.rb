module ApiTestHelper
  def json_body
    JSON.parse(response.body)
  end

  def json_headers
    { "Accept" => "application/json", "Content-Type" => "application/json" }
  end

  def bearer_headers(token)
    json_headers.merge("Authorization" => "Bearer #{token}")
  end

  def api_session_for(user, expires_at: 30.days.from_now)
    user.sessions.create!(
      api_token: SecureRandom.hex(32),
      api_token_expires_at: expires_at
    )
  end

  def sign_in_with_api_token(user)
    session = api_session_for(user)
    [ session, bearer_headers(session.api_token) ]
  end

  def assert_json_error(message, status: nil)
    assert_response(status) if status
    assert_equal message, json_body["error"]
  end

  def assert_json_keys(*keys)
    keys.flatten.each { |key| assert_includes json_body.keys, key.to_s }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ApiTestHelper
end
