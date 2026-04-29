# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVote do
  include_context "as admin"

  it_behaves_like "user_vote score validation", :comment_vote, CommentVote

  # -------------------------------------------------------------------------
  # validate_user_can_vote (CommentVote-specific)
  # -------------------------------------------------------------------------
  describe "validate_user_can_vote" do
    it "is invalid when the user has reached the comment vote limit" do
      voter = create(:user)
      allow(voter).to receive(:can_comment_vote_with_reason).and_return(:REJ_LIMITED)
      vote = build(:comment_vote, user: voter, score: 1)
      expect(vote).not_to be_valid
      expect(vote.errors[:user]).to be_present
    end

    it "is valid when the user is within the comment vote limit" do
      voter = create(:user)
      allow(voter).to receive(:can_comment_vote_with_reason).and_return(true)
      vote = build(:comment_vote, user: voter, score: 1)
      expect(vote).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_comment_can_be_voted (CommentVote-specific)
  # -------------------------------------------------------------------------
  describe "validate_comment_can_be_voted" do
    describe "own comment restriction" do
      it "is invalid when upvoting your own comment" do
        # Make the comment's creator match CurrentUser.
        comment = create(:comment)
        comment.update_columns(creator_id: CurrentUser.user.id)
        vote = build(:comment_vote, comment: comment, user: CurrentUser.user, score: 1)
        expect(vote).not_to be_valid
        expect(vote.errors[:base]).to include("You cannot vote on your own comments")
      end

      it "is invalid when downvoting your own comment" do
        comment = create(:comment)
        comment.update_columns(creator_id: CurrentUser.user.id)
        vote = build(:comment_vote, comment: comment, user: CurrentUser.user, score: -1)
        expect(vote).not_to be_valid
        expect(vote.errors[:base]).to include("You cannot vote on your own comments")
      end

      it "is valid when voting on someone else's comment" do
        other_user = create(:user)
        comment = create(:comment)
        comment.update_columns(creator_id: other_user.id)
        vote = build(:comment_vote, comment: comment, score: 1)
        expect(vote).to be_valid
      end

      it "does not apply the own-comment restriction for locked votes (score 0)" do
        comment = create(:comment)
        comment.update_columns(creator_id: CurrentUser.user.id)
        vote = build(:comment_vote, comment: comment, user: CurrentUser.user, score: 0)
        expect(vote.errors[:base]).not_to include("You cannot vote on your own comments")
      end
    end

    describe "sticky comment restriction" do
      it "is invalid when voting on a sticky comment" do
        sticky = create(:sticky_comment)
        vote = build(:comment_vote, comment: sticky, score: 1)
        expect(vote).not_to be_valid
        expect(vote.errors[:base]).to include("You cannot vote on sticky comments")
      end

      it "is valid when voting on a non-sticky comment" do
        comment = create(:comment)
        comment.update_columns(creator_id: create(:user).id)
        vote = build(:comment_vote, comment: comment, score: 1)
        expect(vote).to be_valid
      end
    end
  end
end
