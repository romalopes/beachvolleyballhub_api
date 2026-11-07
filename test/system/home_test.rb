require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "public home page renders the application name" do
    visit "/"

    assert_title "BVB Hub - Rails"
    assert_text "BEACH VOLLEYBALL PROJECT"
    assert_link "Skills"
    assert_link "Drills"
  end
end
