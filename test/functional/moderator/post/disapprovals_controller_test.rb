# frozen_string_literal: true

require "test_helper"

module Moderator
  module Post
    class DisapprovalsControllerTest < ActionDispatch::IntegrationTest
      context "The moderator post disapprovals controller" do
        setup do
          @user = create(:user)
          @admin = create(:admin_user)
          as(@user) do
            @post = create(:post, is_pending: true)
          end

          CurrentUser.user = @admin
        end

        context "create action" do
          should "render" do
            assert_difference("PostDisapproval.count", 1) do
              post_auth moderator_post_disapprovals_path, @admin, params: { post_disapproval: { post_id: @post.id, reason: "borderline_quality" }, format: :json }
            end
            assert_response :success
          end
        end

        context "index action" do
          should "render" do
            disapproval = create(:post_disapproval, post: @post)
            get_auth moderator_post_disapprovals_path, @admin

            assert_response :success
          end
        end
      end
    end
  end
end
