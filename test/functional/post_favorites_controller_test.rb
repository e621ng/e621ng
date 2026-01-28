# frozen_string_literal: true

require "test_helper"

class PostFavoritesControllerTest < ActionDispatch::IntegrationTest
  context "The post favorites controller" do
    setup do
      @user = create(:user)
      @post = create(:post)
      @favorite = create(:favorite, user: @user, post: @post)
    end

    context "#index" do
      should "work for html" do
        get_auth post_favorites_path(@post), @user
        assert_response :success
      end

      should "work for json and return limited user data" do
        get_auth post_favorites_path(@post, format: :json), @user
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal 1, json.length

        user_data = json.first
        assert_equal @user.id, user_data["id"]
        assert_equal @user.name, user_data["name"]
        assert_equal @user.level_string, user_data["level_string"]
        assert_equal @user.favorite_count, user_data["favorite_count"]

        # Ensure sensitive data is not exposed
        assert_nil user_data["email"]
        assert_nil user_data["created_at"]
        assert_nil user_data["api_key"]
        assert_nil user_data["password_hash"]
      end

      should "respect privacy settings" do
        @user.update!(enable_privacy_mode: true)

        other_user = create(:user)
        get_auth post_favorites_path(@post, format: :json), other_user
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal 0, json.length
      end
    end
  end
end
