# frozen_string_literal: true

require "test_helper"

class CommentVotesControllerTest < ActionDispatch::IntegrationTest
  context "A comment votes controller" do
    setup do
      @user = create(:user)
      @admin = create(:admin_user)
      CurrentUser.user = @user
      @post = create(:post, uploader: @user)
      @comment = create(:comment, post: @post)

      @user2 = create(:user)
      CurrentUser.user = @user2
    end

    context "index action" do
      should "render" do
        get_auth url_for(controller: "comment_votes", action: "index", only_path: true), @admin
        assert_response :success
      end

      context "members" do
        should "render" do
          get_auth url_for(controller: "comment_votes", action: "index", only_path: true), @user2
          assert_response :success
        end

        should "only list own votes" do
          create(:comment_vote, comment: @comment, user: @user2, score: -1)
          create(:comment_vote, comment: @comment, user: @admin, score: 1)

          get_auth url_for(controller: "comment_votes", action: "index", format: "json", only_path: true), @user2
          assert_response :success
          assert_equal(1, response.parsed_body.length)
          assert_equal(@user2.id, response.parsed_body[0]["user_id"])
        end
      end
    end

    context "create action" do
      should "create a vote" do
        assert_difference("CommentVote.count", 1) do
          post_auth comment_votes_path(@comment), @user2, params: { score: -1, format: :json }
          assert_response :success
        end
      end

      should "unvote when the vote already exists" do
        create(:comment_vote, comment: @comment, user: @user2, score: -1)
        assert_difference(-> { CommentVote.count }, -1) do
          post_auth comment_votes_path(@comment), @user2, params: { score: -1, format: :json }
          assert_response :success
        end
      end

      should "prevent voting on comment locked posts" do
        @post.update(is_comment_locked: true)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user2, params: { score: -1, format: :json }
          assert_response 422
        end
      end

      should "prevent unvoting on comment locked posts" do
        @post.update(is_comment_locked: true)
        create(:comment_vote, comment: @comment, user: @user2, score: -1)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user2, params: { score: -1, format: :json }
          assert_response 422
        end
      end

      should "prevent voting on comment disabled posts" do
        @post.update(is_comment_disabled: true)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
          assert_response 422
        end
      end

      should "prevent unvoting on comment disabled posts" do
        @post.update(is_comment_disabled: true)
        create(:comment_vote, comment: @comment, user: @user2, score: -1)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user2, params: { score: -1, format: :json }
          assert_response 422
        end
      end
    end
  end
end
