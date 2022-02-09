require "test_helper"

module Explore
  class PostsControllerTest < ActionDispatch::IntegrationTest
    context "in all cases" do
      setup do
        @user = create(:user)
        as_user do
          create(:post)
        end
      end

      context "#popular" do
        should "render" do
          get popular_explore_posts_path
          assert_response :success
        end
      end
    end
  end
end
