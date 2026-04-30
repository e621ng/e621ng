# frozen_string_literal: true

require "test_helper"

module Moderator
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    context "The moderator dashboards controller" do
      setup do
        @user = create(:privileged_user, created_at: 1.month.ago)
        @admin = create(:admin_user)
      end

      context "show action" do
        context "for mod actions" do
          setup do
            as(@admin) do
              @mod_action = create(:mod_action)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for user feedbacks" do
          setup do
            as(@admin) do
              @feedback = create(:user_feedback)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for wiki pages" do
          setup do
            as(@user) do
              @wiki_page = create(:wiki_page)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for tags and uploads" do
          setup do
            as(@user) do
              @post = create(:post)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for notes" do
          setup do
            as(@user) do
              @post = create(:post)
              @note = create(:note, post_id: @post.id)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for comments" do
          setup do
            @users = (0..5).map { create(:user) }

            as(create(:user)) do
              @comment = create(:comment)
            end

            @users.each do |user|
              as(user) do
                VoteManager.comment_vote!(user: user, comment: @comment, score: -1)
              end
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for artists" do
          setup do
            as(@user) do
              @artist = create(:artist)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end

        context "for flags" do
          setup do
            as(@user) do
              @post = create(:post)
              create(:post_flag, post: @post)
            end
          end

          should "render" do
            get_auth moderator_dashboard_path, @admin
            assert_response :success
          end
        end
      end
    end
  end
end
