# frozen_string_literal: true

require "test_helper"

class PostVoteTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 1.month.ago)
    CurrentUser.user = @user

    @post = create(:post)
  end

  context "Validating vote scores" do
    should "accept upvote (+1)" do
      vote = VoteManager.vote!(user: @user, post: @post, score: 1)
      assert_equal(1, vote.score)
    end

    should "accept downvote (-1)" do
      vote = VoteManager.vote!(user: @user, post: @post, score: -1)
      assert_equal(-1, vote.score)
    end

    should "reject invalid scores" do
      error = assert_raises(UserVote::Error) { VoteManager.vote!(user: @user, post: @post, score: 0) }
      assert_equal("Invalid vote", error.message)

      error = assert_raises(UserVote::Error) { VoteManager.vote!(user: @user, post: @post, score: 2) }
      assert_equal("Invalid vote", error.message)

      error = assert_raises(UserVote::Error) { VoteManager.vote!(user: @user, post: @post, score: "xxx") }
      assert_equal("Invalid vote", error.message)
    end

    should "require member-level permissions" do
      @user.update_column(:level, User::Levels::MEMBER - 1)
      error = assert_raises(UserVote::Error) { VoteManager.vote!(user: @user, post: @post, score: 1) }
      assert_equal("You do not have permission to vote", error.message)
    end
  end

  context "Creating vote" do
    should "create upvote record and update post columns" do
      vote = VoteManager.vote!(user: @user, post: @post, score: 1)

      assert_equal(1, vote.score)
      assert_equal(@user.id, vote.user_id)
      assert_equal(@post.id, vote.post_id)

      @post.reload
      assert_equal(1, @post.score)
      assert_equal(1, @post.up_score)
      assert_equal(0, @post.down_score)
    end

    should "create downvote record and update post columns" do
      vote = VoteManager.vote!(user: @user, post: @post, score: -1)

      assert_equal(-1, vote.score)
      assert_equal(@user.id, vote.user_id)
      assert_equal(@post.id, vote.post_id)

      @post.reload
      assert_equal(-1, @post.score)
      assert_equal(0, @post.up_score)
      assert_equal(-1, @post.down_score)
    end
  end

  context "Replacing a downvote with an upvote" do
    setup do
      VoteManager.vote!(user: @user, post: @post, score: -1)
      @post.reload
    end

    should "replace vote record and update all post columns correctly" do
      VoteManager.vote!(user: @user, post: @post, score: 1)

      assert_equal(1, PostVote.where(user: @user, post: @post).count)
      vote = PostVote.find_by(user: @user, post: @post)
      assert_equal(1, vote.score)

      @post.reload
      assert_equal(1, @post.score) # was -1, now +1 (change of +2)
      assert_equal(1, @post.up_score) # was 0, now 1
      assert_equal(0, @post.down_score) # was 1, now 0
    end
  end

  context "Replacing an upvote with a downvote" do
    setup do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      @post.reload
    end

    should "replace vote record and update all post columns correctly" do
      VoteManager.vote!(user: @user, post: @post, score: -1)

      assert_equal(1, PostVote.where(user: @user, post: @post).count)
      vote = PostVote.find_by(user: @user, post: @post)
      assert_equal(-1, vote.score)

      @post.reload
      assert_equal(-1, @post.score) # was +1, now -1 (change of -2)
      assert_equal(0, @post.up_score) # was 1, now 0
      assert_equal(-1, @post.down_score) # was 0, now -1
    end
  end

  context "Voting the same way twice" do
    should "return :need_unvote and not upvote again" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      @post.reload
      original_score = @post.score
      original_up_score = @post.up_score
      original_down_score = @post.down_score

      result = VoteManager.vote!(user: @user, post: @post, score: 1)
      assert_equal(:need_unvote, result)
      @post.reload

      assert_equal(original_score, @post.score)
      assert_equal(original_up_score, @post.up_score)
      assert_equal(original_down_score, @post.down_score)
    end

    should "return :need_unvote and not downvote again" do
      VoteManager.vote!(user: @user, post: @post, score: -1)
      @post.reload
      original_score = @post.score
      original_up_score = @post.up_score
      original_down_score = @post.down_score

      result = VoteManager.vote!(user: @user, post: @post, score: -1)
      assert_equal(:need_unvote, result)
      @post.reload

      assert_equal(original_score, @post.score)
      assert_equal(original_up_score, @post.up_score)
      assert_equal(original_down_score, @post.down_score)
    end
  end

  context "Removing an upvote" do
    setup do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      @post.reload
    end

    should "delete vote record and update all post columns correctly" do
      VoteManager.unvote!(user: @user, post: @post)
      assert_equal(0, PostVote.where(user: @user, post: @post).count)

      @post.reload
      assert_equal(0, @post.score)
      assert_equal(0, @post.up_score)
      assert_equal(0, @post.down_score)
    end
  end

  context "Removing a downvote" do
    setup do
      VoteManager.vote!(user: @user, post: @post, score: -1)
      @post.reload
    end

    should "delete vote record and update all post columns correctly" do
      VoteManager.unvote!(user: @user, post: @post)
      assert_equal(0, PostVote.where(user: @user, post: @post).count)

      @post.reload
      assert_equal(0, @post.score)
      assert_equal(0, @post.up_score)
      assert_equal(0, @post.down_score)
    end
  end

  context "Removing a vote that doesn't exist" do
    should "not raise an error or change post scores" do
      original_score = @post.score
      original_up_score = @post.up_score
      original_down_score = @post.down_score

      assert_nothing_raised do
        VoteManager.unvote!(user: @user, post: @post)
      end

      @post.reload
      assert_equal(original_score, @post.score)
      assert_equal(original_up_score, @post.up_score)
      assert_equal(original_down_score, @post.down_score)
    end
  end

  context "Locked votes" do
    setup do
      @vote = VoteManager.vote!(user: @user, post: @post, score: 1)
      VoteManager.lock!(@vote.id)
      @post.reload
    end

    should "prevent voting again" do
      error = assert_raises(UserVote::Error) do
        VoteManager.vote!(user: @user, post: @post, score: 1)
      end
      assert_equal("Vote is locked", error.message)
    end

    should "prevent unvoting" do
      error = assert_raises(UserVote::Error) do
        VoteManager.unvote!(user: @user, post: @post)
      end
      assert_equal("You can't remove locked votes", error.message)
    end

    should "allow unvoting with force flag" do
      assert_nothing_raised do
        VoteManager.unvote!(user: @user, post: @post, force: true)
      end
    end

    should "set vote score to 0 when locked" do
      @vote.reload
      assert_equal(0, @vote.score)
    end
  end

  context "Multiple users voting on the same post" do
    setup do
      @user2 = create(:user, created_at: 1.month.ago)
      @user3 = create(:user, created_at: 1.month.ago)
    end

    should "correctly accumulate upvotes" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      VoteManager.vote!(user: @user2, post: @post, score: 1)
      VoteManager.vote!(user: @user3, post: @post, score: 1)

      @post.reload
      assert_equal(3, @post.score)
      assert_equal(3, @post.up_score)
      assert_equal(0, @post.down_score)
    end

    should "correctly accumulate downvotes" do
      VoteManager.vote!(user: @user, post: @post, score: -1)
      VoteManager.vote!(user: @user2, post: @post, score: -1)
      VoteManager.vote!(user: @user3, post: @post, score: -1)

      @post.reload
      assert_equal(-3, @post.score)
      assert_equal(0, @post.up_score)
      assert_equal(-3, @post.down_score)
    end

    should "correctly handle mixed votes" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      VoteManager.vote!(user: @user2, post: @post, score: 1)
      VoteManager.vote!(user: @user3, post: @post, score: -1)

      @post.reload
      assert_equal(1, @post.score)
      assert_equal(2, @post.up_score)
      assert_equal(-1, @post.down_score)
    end

    should "correctly handle vote changes from multiple users" do
      VoteManager.vote!(user: @user, post: @post, score: 1)
      VoteManager.vote!(user: @user2, post: @post, score: -1)
      @post.reload
      assert_equal(0, @post.score)
      assert_equal(1, @post.up_score)
      assert_equal(-1, @post.down_score)

      VoteManager.vote!(user: @user, post: @post, score: -1) # Change from +1 to -1
      @post.reload
      assert_equal(-2, @post.score)
      assert_equal(0, @post.up_score)
      assert_equal(-2, @post.down_score)
    end
  end
end
