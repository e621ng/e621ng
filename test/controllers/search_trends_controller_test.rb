# frozen_string_literal: true

require "test_helper"

class SearchTrendsControllerTest < ActionDispatch::IntegrationTest
  test "index renders html" do
    SearchTrend.increment!("wolf")
    get "/search_trends"
    assert_response :success
    assert_match(/Trending tags/, response.body)
  end

  test "index returns json" do
    SearchTrend.increment!("fox")
    get "/search_trends.json"
    assert_response :success
    json = response.parsed_body
    assert(json.is_a?(Array))
    assert(json.any? { |row| row["tag"] == "fox" })
  end
end
