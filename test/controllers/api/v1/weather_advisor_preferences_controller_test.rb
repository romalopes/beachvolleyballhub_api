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
    assert_equal expected_weights, JSON.parse(response.body).symbolize_keys
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
    assert_equal expected_weights, JSON.parse(response.body).symbolize_keys
    assert_nil accounts(:one).reload.weather_advisor_preference
  end

  private

  def expected_weights
    WeatherAdvisorPreference::DEFAULT_WEIGHTS.transform_keys { |factor| :"#{factor}_weight" }
  end
end