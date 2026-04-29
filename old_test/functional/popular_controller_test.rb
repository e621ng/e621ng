# frozen_string_literal: true

require "test_helper"

class PopularControllerTest < ActionDispatch::IntegrationTest
  context "#index" do
    should "render" do
      get popular_index_path
      assert_response :success
    end

    should "handle invalid date parameter" do
      get popular_index_path(date: "@@bGNva")
      assert_response 422
    end

    should "handle blank date parameter" do
      get popular_index_path(date: "")
      assert_response :success
    end
  end
end
