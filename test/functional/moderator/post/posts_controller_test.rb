# frozen_string_literal: true

require "test_helper"

module Moderator
  module Post
    class PostsControllerTest < ActionDispatch::IntegrationTest
      context "The moderator posts controller" do
        setup do
          @admin = create(:admin_user)
          @user = create(:privileged_user, created_at: 1.month.ago)

          as(@user) do
            @post = create(:post)
          end
        end

        context "confirm_delete action" do
          should "render" do
            get_auth confirm_delete_moderator_post_post_path(@post), @admin
            assert_response :success
          end
        end

        context "delete action" do
          should "render" do
            post_auth delete_moderator_post_post_path(@post), @admin, params: { reason: "xxx", format: "js", commit: "Delete" }
            assert(@post.reload.is_deleted?)
          end

          should "work even if the deleter has flagged the post previously" do
            as(@user) do
              PostFlag.create(post: @post, reason: "aaa", is_resolved: false)
            end
            post_auth delete_moderator_post_post_path(@post), @admin, params: { reason: "xxx", format: "js", commit: "Delete" }
            assert(@post.reload.is_deleted?)
          end
        end

        context "undelete action" do
          should "render" do
            as(@user) do
              @post.delete! "test delete"
            end
            assert_difference(-> { PostEvent.count }, 1) do
              post_auth undelete_moderator_post_post_path(@post), @admin, params: { format: :json }
            end

            assert_response :success
            assert_not(@post.reload.is_deleted?)
          end
        end

        context "move_favorites action" do
          setup do
            @admin = create(:admin_user)
          end

          should "render" do
            as(@user) do
              @parent = create(:post)
              @child = create(:post, parent: @parent)
            end
            users = create_list(:user, 2)
            users.each do |u|
              FavoriteManager.add!(user: u, post: @child)
              @child.reload
            end

            post_auth move_favorites_moderator_post_post_path(@child.id), @admin, params: { commit: "Submit" }
            assert_redirected_to(@child)
            perform_enqueued_jobs(only: TransferFavoritesJob)
            @parent.reload
            @child.reload
            as(@admin) do
              assert_equal(users.map(&:id).sort, @parent.favorited_users.map(&:id).sort)
              assert_equal([], @child.favorited_users.map(&:id))
            end
          end
        end

        context "expunge action" do
          should "render" do
            post_auth expunge_moderator_post_post_path(@post), @admin, params: { format: :json }

            assert_response :success
            assert_equal(false, ::Post.exists?(@post.id))
          end
        end
      end
    end
  end
end
