# frozen_string_literal: true

require "test_helper"

class PostFlagsControllerTest < ActionDispatch::IntegrationTest
  context "The post flags controller" do
    setup do
      @user = create(:user, created_at: 2.weeks.ago)
    end

    context "new action" do
      should "render" do
        @post = create(:post, uploader: @user)
        get_auth new_post_flag_path, @user, params: { post_flag: { post_id: @post.id } }
        assert_response :success
      end
    end

    context "index action" do
      setup do
        as(@user) do
          @post = create(:post)
          @post_flag = create(:post_flag, post: @post)
        end
      end

      should "render" do
        get_auth post_flags_path, @user
        assert_response :success
      end

      context "with search parameters" do
        should "render" do
          get_auth post_flags_path, @user, params: {:search => {:post_id => @post_flag.post_id}}
          assert_response :success
        end
      end
    end

    context "create action" do
      setup do
        as(@user) do
          @post = create(:post)
        end
      end

      should "create a new flag" do
        assert_difference("PostFlag.count", 1) do
          post_auth post_flags_path, @user, params: { format: :json, post_flag: { post_id: @post.id, reason_name: "dnp_artist" } }
        end
      end
    end
  end
end
