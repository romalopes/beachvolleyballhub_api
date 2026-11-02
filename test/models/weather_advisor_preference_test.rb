require "test_helper"

class WeatherAdvisorPreferenceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "database defaults produce the documented distribution" do
    preference = @account.create_weather_advisor_preference!

    assert_equal WeatherAdvisorPreference.defaults, preference.weights
    assert_equal({ wind: 40, temperature: 20, rain: 25, uv: 5, humidity: 10 }, preference.weights)
    assert_equal 100, preference.weights.values.sum
  end

  test "accepts a valid custom distribution including boundary values" do
    preference = @account.build_weather_advisor_preference(
      wind_weight: 100,
      temperature_weight: 0,
      rain_weight: 0,
      uv_weight: 0,
      humidity_weight: 0
    )

    assert_predicate preference, :valid?
  end

  test "rejects weights outside the zero through one hundred range" do
    below_range = @account.build_weather_advisor_preference(wind_weight: -1, humidity_weight: 51)
    above_range = @account.build_weather_advisor_preference(wind_weight: 101, humidity_weight: -1)

    assert_not below_range.valid?
    assert_includes below_range.errors[:wind_weight], "must be greater than or equal to 0"
    assert_not above_range.valid?
    assert_includes above_range.errors[:wind_weight], "must be less than or equal to 100"
  end

  test "rejects non-integer weights" do
    preference = @account.build_weather_advisor_preference(wind_weight: 40.5, humidity_weight: 9.5)

    assert_not preference.valid?
    assert_includes preference.errors[:wind_weight], "must be an integer"
  end

  test "rejects a total other than one hundred" do
    below_total = @account.build_weather_advisor_preference(humidity_weight: 9)
    above_total = @account.build_weather_advisor_preference(humidity_weight: 11)

    assert_not below_total.valid?
    assert_includes below_total.errors[:base], "Weights must sum to 100"
    assert_not above_total.valid?
    assert_includes above_total.errors[:base], "Weights must sum to 100"
  end

  test "a missing weight is invalid without raising from total validation" do
    preference = @account.build_weather_advisor_preference(wind_weight: nil)

    assert_not preference.valid?
    assert_includes preference.errors.attribute_names, :wind_weight
  end

  test "is unique per account" do
    @account.create_weather_advisor_preference!

    duplicate = WeatherAdvisorPreference.new(account: @account)
    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :account_id
  end

  test "the database enforces one preference per account" do
    @account.create_weather_advisor_preference!
    timestamp = Time.current

    assert_raises ActiveRecord::RecordNotUnique do
      WeatherAdvisorPreference.insert_all!([ preference_row(@account, timestamp:) ])
    end
  end

  test "the database enforces the weight range" do
    timestamp = Time.current

    assert_raises ActiveRecord::CheckViolation do
      WeatherAdvisorPreference.insert_all!([
        preference_row(@account, timestamp:, wind_weight: 101, humidity_weight: -1)
      ])
    end
  end

  test "the database enforces a total of one hundred" do
    timestamp = Time.current

    assert_raises ActiveRecord::CheckViolation do
      WeatherAdvisorPreference.insert_all!([
        preference_row(@account, timestamp:, humidity_weight: 9)
      ])
    end
  end

  test "destroying an account destroys its weather advisor preference" do
    account = create_account!(first_name: "Weather", last_name: "Owner")
    preference = account.create_weather_advisor_preference!

    assert_difference("WeatherAdvisorPreference.where(id: #{preference.id}).count", -1) do
      account.destroy
    end
  end

  private

  def preference_row(account, timestamp:, **overrides)
    {
      account_id: account.id,
      wind_weight: 40,
      temperature_weight: 20,
      rain_weight: 25,
      uv_weight: 5,
      humidity_weight: 10,
      created_at: timestamp,
      updated_at: timestamp
    }.merge(overrides)
  end
end
