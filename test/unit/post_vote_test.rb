# frozen_string_literal: true

require "test_helper"

class PostVoteTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 1.month.ago)
    CurrentUser.user = @user

    @post = create(:post)
  end

  context "Voting for a post" do
    should "interpret up as +1 score" do
      vote = VoteManager.vote!(user: @user, post: @post, score: 1)
      assert_equal(1, vote.score)
    end

    should "interpret down as -1 score" do
      vote = VoteManager.vote!(user: @user, post: @post, score: -1)
      assert_equal(-1, vote.score)
    end

    should "not accept any other scores" do
      error = assert_raises(UserVote::Error) { VoteManager.vote!(user: @user, post: @post, score: 'xxx') }
      assert_equal("Invalid vote", error.message)
    end

    should "increase the score of the post" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      @post.reload

      assert_equal(1, @post.score)
      assert_equal(1, @post.up_score)
    end

    should "decrease the score of the post when removed" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      @post.reload
      assert_equal(1, @post.score)
      assert_equal(1, @post.up_score)

      VoteManager.unvote!(user: @user, post: @post)
      @post.reload

      assert_equal(0, @post.score)
      assert_equal(0, @post.up_score)
    end
  end
end
