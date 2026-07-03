# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comment do
  include_context "as admin"

  describe "VoteMethods" do
    describe "#vote_by" do
      it "returns 0 when the user has not voted" do
        user    = create(:user)
        comment = create(:comment)
        expect(comment.vote_by(user.id)).to eq(0)
      end

      it "returns the score when the user has upvoted" do
        vote = create(:comment_vote)
        expect(vote.comment.vote_by(vote.user_id)).to eq(1)
      end

      it "returns the score when the user has downvoted" do
        vote = create(:down_comment_vote)
        expect(vote.comment.vote_by(vote.user_id)).to eq(-1)
      end

      it "returns 0 for a locked vote (score: 0)" do
        vote = create(:locked_comment_vote)
        expect(vote.comment.vote_by(vote.user_id)).to eq(0)
      end

      it "returns 0 for a blank user id" do
        comment = create(:comment)
        expect(comment.vote_by(nil)).to eq(0)
      end

      it "uses the preloaded cache instead of hitting the database" do
        comment = create(:comment)
        comment.preset_vote_by(42, 1)
        allow(CommentVote).to receive(:where)
        expect(comment.vote_by(42)).to eq(1)
        expect(CommentVote).not_to have_received(:where)
      end

      it "uses a preloaded 0 instead of hitting the database" do
        comment = create(:comment)
        comment.preset_vote_by(42, 0)
        allow(CommentVote).to receive(:where)
        expect(comment.vote_by(42)).to eq(0)
        expect(CommentVote).not_to have_received(:where)
      end
    end

    describe ".preload_vote_by!" do
      it "primes the cache with the user's vote scores for the given comments" do
        upvote     = create(:comment_vote)
        downvote   = create(:down_comment_vote, user: upvote.user)
        unvoted    = create(:comment)

        Comment.preload_vote_by!([upvote.comment, downvote.comment, unvoted], upvote.user_id)
        expect(upvote.comment.vote_by(upvote.user_id)).to eq(1)
        expect(downvote.comment.vote_by(upvote.user_id)).to eq(-1)
        expect(unvoted.vote_by(upvote.user_id)).to eq(0)
      end

      it "is a no-op for a blank user id" do
        comment = create(:comment)
        expect { Comment.preload_vote_by!([comment], nil) }.not_to(change { comment.instance_variable_get(:@vote_by_cache) })
      end

      it "is a no-op for an empty comment list" do
        expect { Comment.preload_vote_by!([], 1) }.not_to raise_error
      end

      it "accepts a single comment" do
        vote = create(:comment_vote)
        Comment.preload_vote_by!(vote.comment, vote.user_id)
        expect(vote.comment.vote_by(vote.user_id)).to eq(1)
      end
    end
  end
end
