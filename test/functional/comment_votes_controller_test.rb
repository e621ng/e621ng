# frozen_string_literal: true

require "test_helper"

class CommentVotesControllerTest < ActionDispatch::IntegrationTest
  context "A comment votes controller" do
    setup do
      @user = create(:user)
      @post = create(:post, uploader: @user)
      CurrentUser.user = @user
      @comment = create(:comment, post: @post)

      @user = create(:user)
      CurrentUser.user = @user
    end

    context "create action" do
      should "create a vote" do
        assert_difference("CommentVote.count", 1) do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
          assert_response :success
        end
      end

      should "unvote when the vote already exists" do
        create(:comment_vote, comment: @comment, user: @user, score: -1)
        assert_difference(-> { CommentVote.count }, -1) do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
          assert_response :success
        end
      end

      should "prevent voting on comment locked posts" do
        @post.update(is_comment_locked: true)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
          assert_response 422
        end
      end

      should "prevent unvoting on comment locked posts" do
        @post.update(is_comment_locked: true)
        create(:comment_vote, comment: @comment, user: @user, score: -1)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
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
        create(:comment_vote, comment: @comment, user: @user, score: -1)
        assert_no_difference("CommentVote.count") do
          post_auth comment_votes_path(@comment), @user, params: { score: -1, format: :json }
          assert_response 422
        end
      end
    end
  end
end
