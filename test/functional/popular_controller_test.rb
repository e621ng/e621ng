# frozen_string_literal: true

require "test_helper"

class PopularControllerTest < ActionDispatch::IntegrationTest
  context "#index" do
    should "render" do
      get popular_index_path
      assert_response :success
    end
  end
end
