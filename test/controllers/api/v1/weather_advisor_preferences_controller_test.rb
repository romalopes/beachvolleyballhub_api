require "test_helper"

class Api::V1::WeatherAdvisorPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:five)
    @other_user = users(:six)
    accounts(:one).weather_advisor_preference&.destroy!
    accounts(:two).weather_advisor_preference&.destroy!
  end

  test "show requires authentication" do
    get "/api/v1/weather_advisor_preference", as: :json

    assert_response :unauthorized
  end

  test "show materialises and returns defaults" do
    sign_in_as(@owner)

    get "/api/v1/weather_advisor_preference"

    assert_response :success
    body = JSON.parse(response.body).symbolize_keys
    assert_equal expected_weights, body.slice(*expected_weights.keys)
    assert_equal Weather::AdvisorPreferences.default_conditions.deep_stringify_keys, body[:conditions]
    assert_equal Weather::AdvisorPreferences.default_directions.stringify_keys, body[:wind_direction_preferences]
    assert_equal expected_weights, accounts(:one).reload.weather_advisor_preference.attributes.symbolize_keys.slice(*expected_weights.keys)
  end

  test "update persists only the current account preferences" do
    other = accounts(:two).create_weather_advisor_preference!
    sign_in_as(@owner)

    patch "/api/v1/weather_advisor_preference", params: {
      weather_advisor_preference: {
        wind_weight: 10,
        temperature_weight: 30,
        rain_weight: 20,
        uv_weight: 20,
        humidity_weight: 20
      }
    }, as: :json

    assert_response :success
    assert_equal 10, accounts(:one).reload.weather_advisor_preference.wind_weight
    assert_equal expected_weights, other.reload.attributes.symbolize_keys.slice(*expected_weights.keys)
  end

  test "update persists nested conditions and wind direction preferences" do
    sign_in_as(@owner)

    patch "/api/v1/weather_advisor_preference", params: {
      weather_advisor_preference: {
        wind_weight: 10,
        temperature_weight: 30,
        rain_weight: 20,
        uv_weight: 20,
        humidity_weight: 20,
        conditions: {
          temperature: { min_c: 8, ideal_min_c: 18, ideal_max_c: 27, max_c: 38 },
          wind: { ideal_max_kph: 12, comfortable_max_kph: 18, high_kph: 35 },
          rain: { preferred_max_percent: 15, comfortable_max_percent: 35, high_percent: 75 },
          uv: { preferred_max: 4, comfortable_max: 7, high: 9 },
          humidity: { preferred_max_percent: 55, comfortable_max_percent: 65, high_percent: 85 }
        },
        wind_direction_preferences: {
          "NE" => "bad",
          "SW" => "very_bad"
        }
      }
    }, as: :json

    assert_response :success
    preference = accounts(:one).reload.weather_advisor_preference

    # Nested hashes survive strong parameters (open-hash permit).
    assert_equal 8, preference.conditions.dig("temperature", "min_c")
    assert_equal 18, preference.conditions.dig("temperature", "ideal_min_c")
    assert_equal 12, preference.conditions.dig("wind", "ideal_max_kph")
    assert_equal 18, preference.conditions.dig("wind", "comfortable_max_kph")
    assert_equal 35, preference.conditions.dig("wind", "high_kph")
    assert_equal 15, preference.conditions.dig("rain", "preferred_max_percent")
    assert_equal 4, preference.conditions.dig("uv", "preferred_max")
    assert_equal 55, preference.conditions.dig("humidity", "preferred_max_percent")
    assert_equal "bad", preference.wind_direction_preferences["NE"]
    assert_equal "very_bad", preference.wind_direction_preferences["SW"]

    # The effective (normalized) values are echoed back with complete defaults.
    body = JSON.parse(response.body).symbolize_keys
    assert_equal 10, body[:wind_weight]
    assert_equal 18, body[:conditions].dig("temperature", "ideal_min_c")
    assert_equal 35, body[:conditions].dig("wind", "high_kph")
    assert_equal "bad", body[:wind_direction_preferences]["NE"]
    assert_equal "very_bad", body[:wind_direction_preferences]["SW"]
    assert_equal "neutral", body[:wind_direction_preferences]["N"],
      "directions not sent remain neutral"
  end

  test "update rejects invalid nested condition values" do
    sign_in_as(@owner)

    patch "/api/v1/weather_advisor_preference", params: {
      weather_advisor_preference: {
        conditions: { temperature: { min_c: "not-a-number" } }
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"), "Conditions must contain numeric values"
  end

  test "update rejects invalid wind direction values" do
    sign_in_as(@owner)

    patch "/api/v1/weather_advisor_preference", params: {
      weather_advisor_preference: {
        wind_direction_preferences: { "NE" => "unbearable" }
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"),
      "Wind direction preferences contains an invalid preference"
  end

  test "update rejects totals other than 100" do
    sign_in_as(@owner)

    patch "/api/v1/weather_advisor_preference", params: {
      weather_advisor_preference: expected_weights.merge(wind_weight: 39)
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"), "Weights must sum to 100"
  end

  test "destroy removes the override and returns defaults" do
    accounts(:one).create_weather_advisor_preference!(
      wind_weight: 10,
      temperature_weight: 30,
      rain_weight: 20,
      uv_weight: 20,
      humidity_weight: 20
    )
    sign_in_as(@owner)

    delete "/api/v1/weather_advisor_preference"

    assert_response :success
    body = JSON.parse(response.body).symbolize_keys
    assert_equal expected_weights, body.slice(*expected_weights.keys)
    assert_equal Weather::AdvisorPreferences.default_conditions.deep_stringify_keys, body[:conditions]
    assert_equal Weather::AdvisorPreferences.default_directions.stringify_keys, body[:wind_direction_preferences]
    assert_nil accounts(:one).reload.weather_advisor_preference
  end

  private

  def expected_weights
    WeatherAdvisorPreference::DEFAULT_WEIGHTS.transform_keys { |factor| :"#{factor}_weight" }
  end
end
