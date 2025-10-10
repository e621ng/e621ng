# frozen_string_literal: true

require "test_helper"

class SearchTrendsControllerTest < ActionDispatch::IntegrationTest
  context "with trends enabled" do
    should "index renders html" do
      SearchTrend.increment!("wolf")
      get "/search_trends"
      assert_response :success
      assert_match(/Trending tags/, response.body)
    end

    should "index returns json" do
      SearchTrend.increment!("fox")
      get "/search_trends.json"
      assert_response :success
      json = response.parsed_body
      assert(json.is_a?(Array))
      assert(json.any? { |row| row["tag"] == "fox" })
    end
  end

  context "settings page" do
    setup do
      @admin = create(:admin_user)
    end

    should "settings page renders for admin" do
      get_auth settings_search_trends_path, @admin
      assert_response :success
      assert_match(/Search trend settings/, response.body)
      assert_match(/Minimum searches today/, response.body)
    end

    should "settings page forbidden for non-admin" do
      user = create(:member_user)
      get_auth settings_search_trends_path, user
      assert_response 403
    end

    should "form submission updates settings" do
      post_auth update_settings_search_trends_path, @admin, params: {
        trends_enabled: false,
        trends_min_today: 11,
        trends_min_delta: 12,
        trends_min_ratio: 2.5,
      }
      assert_redirected_to search_trends_path
      assert_equal false, Setting.trends_enabled?
      assert_equal 11, Setting.trends_min_today
      assert_equal 12, Setting.trends_min_delta
      assert_in_delta 2.5, Setting.trends_min_ratio, 0.001
      assert_nil Rails.cache.read("rising_tags"), "cache should be cleared"
    end
  end
end
