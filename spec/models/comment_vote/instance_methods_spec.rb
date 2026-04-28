# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVote do
  include_context "as admin"

  it_behaves_like "user_vote instance methods", :comment_vote, CommentVote
  it_behaves_like "user_vote initialize",       :comment_vote, CommentVote

  # -------------------------------------------------------------------------
  # CommentVote-specific class methods
  # -------------------------------------------------------------------------
  describe ".model_type" do
    it "returns :comment" do
      expect(CommentVote.model_type).to eq(:comment)
    end
  end

  describe ".model_creator_column" do
    it "returns :creator" do
      expect(CommentVote.model_creator_column).to eq(:creator)
    end
  end

  describe ".for_comments_and_user" do
    it "returns a hash keyed by comment_id for the given user" do
      voter   = create(:user)
      vote_a  = create(:comment_vote, user: voter)
      vote_b  = create(:comment_vote, user: voter)

      result = CommentVote.for_comments_and_user([vote_a.comment_id, vote_b.comment_id], voter.id)

      expect(result).to be_a(Hash)
      expect(result[vote_a.comment_id]).to eq(vote_a)
      expect(result[vote_b.comment_id]).to eq(vote_b)
    end

    it "excludes votes from other users" do
      voter       = create(:user)
      other_voter = create(:user)
      vote        = create(:comment_vote, user: voter)
      _other      = create(:comment_vote, user: other_voter, comment: vote.comment)

      result = CommentVote.for_comments_and_user([vote.comment_id], voter.id)
      expect(result[vote.comment_id]).to eq(vote)
    end

    it "returns an empty hash when user_id is nil" do
      vote   = create(:comment_vote)
      result = CommentVote.for_comments_and_user([vote.comment_id], nil)
      expect(result).to eq({})
    end

    it "returns an empty hash when the comment list is empty" do
      voter  = create(:user)
      result = CommentVote.for_comments_and_user([], voter.id)
      expect(result).to eq({})
    end
  end
end
