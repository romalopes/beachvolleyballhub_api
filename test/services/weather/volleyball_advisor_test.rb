require "test_helper"

class Weather::VolleyballAdvisorTest < ActiveSupport::TestCase
  def assess(current = {}, rain_chance_percent: nil)
    Weather::VolleyballAdvisor.assess(current: current, rain_chance_percent: rain_chance_percent)
  end

  test "calm, mild conditions score excellent with no warnings" do
    result = assess(
      {
        wind_kph: 8.0,
        wind_gust_kph: 10.0,
        temperature_c: 24.0,
        feels_like_c: 24.0,
        uv_index: 4.0,
        humidity_percent: 55
      },
      rain_chance_percent: 10
    )

    assert_equal 100, result[:score]
    assert_equal "Excellent", result[:label]
    assert_empty result[:warnings]
    assert_not result[:safety_override]
    assert_includes result[:advice].first, "Calm wind"
  end

  test "strong wind triggers a safety warning and lowers the score" do
    result = assess({ wind_kph: 45.0, wind_gust_kph: 50.0, temperature_c: 24.0 })

    assert result[:score] < 50
    assert_includes result[:warnings], "Dangerous gusts: postpone play and secure equipment."
    assert result[:safety_override]
  end

  test "gustiness adds both advice and a score penalty" do
    calm = assess({ wind_kph: 18.0, temperature_c: 24.0 })
    gusty = assess({ wind_kph: 18.0, wind_gust_kph: 40.0, temperature_c: 24.0 })

    assert gusty[:score] < calm[:score]
    assert_includes gusty[:advice].last, "Gusty conditions"
  end

  test "extreme feels-like heat warns independently of the score" do
    result = assess({ wind_kph: 5.0, temperature_c: 39.0, feels_like_c: 41.0 })

    assert_includes result[:warnings], "Extreme heat: high risk of heat stress; avoid strenuous play."
    assert result[:safety_override]
    assert_includes result[:advice], "Hot conditions: hydrate frequently and take shade breaks."
  end

  test "heavy rain chance warns and drags the score down" do
    result = assess({ wind_kph: 10.0, temperature_c: 22.0 }, rain_chance_percent: 85)

    assert_equal 74, result[:score] # 25% rain weight drops a perfect day to "Good"
    assert_equal "Good", result[:label]
    assert_includes result[:warnings], "Heavy rain expected: sand and surrounding surfaces may be unsafe."
    assert result[:safety_override]
  end

  test "extreme UV warns without a high wind or rain penalty" do
    result = assess({ wind_kph: 5.0, temperature_c: 22.0, uv_index: 11.0 })

    assert_includes result[:warnings], "Extreme UV: limit time in direct sun."
    assert result[:safety_override]
  end

  test "missing data renormalises weights instead of failing" do
    result = assess({ wind_kph: 12.0 })

    assert_equal 85, result[:score] # wind 85 with its full 40% weight
    assert_equal "Excellent", result[:label]
    assert_empty result[:warnings]
  end

  test "no data at all scores unknown with no safety claims" do
    result = assess({})

    assert_nil result[:score]
    assert_equal "Unknown", result[:label]
    assert_empty result[:advice]
    assert_empty result[:warnings]
    assert_not result[:safety_override]
  end

  test "numeric strings are accepted and malformed values are ignored" do
    result = assess(
      {
        wind_kph: "12.5",
        temperature_c: "not-a-number",
        humidity_percent: Float::INFINITY
      },
      rain_chance_percent: "20"
    )

    assert_equal 91, result[:score]
    assert_equal "Excellent", result[:label]
    assert_empty result[:warnings]
  end

  test "labels follow the plan bands" do
    {
      90 => "Excellent", 75 => "Good", 55 => "Fair", 35 => "Poor", 10 => "Unsuitable"
    }.each do |band_score, expected_label|
      assert_equal expected_label, Weather::VolleyballAdvisor.new(current: {}).send(:label_for, band_score)
    end
  end
end