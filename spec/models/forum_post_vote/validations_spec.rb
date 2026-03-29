# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumPostVote Validations                             #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPostVote do
  include_context "as member"

  # -------------------------------------------------------------------------
  # score inclusion
  # -------------------------------------------------------------------------
  describe "score" do
    it "is valid with score 1" do
      expect(build(:forum_post_vote, score: 1)).to be_valid
    end

    it "is valid with score -1" do
      expect(build(:forum_post_vote, score: -1)).to be_valid
    end

    it "is valid with score 0" do
      expect(build(:forum_post_vote, score: 0)).to be_valid
    end

    it "is invalid with score 2" do
      record = build(:forum_post_vote, score: 2)
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end

    it "is invalid with score -2" do
      record = build(:forum_post_vote, score: -2)
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end

    it "is invalid with a nil score" do
      record = build(:forum_post_vote, score: nil)
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # creator uniqueness per forum post
  # -------------------------------------------------------------------------
  describe "creator uniqueness" do
    let(:post) { create(:forum_post) }

    it "is invalid when the same user votes on the same post twice" do
      create(:forum_post_vote, forum_post: post)
      duplicate = build(:forum_post_vote, forum_post: post)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:creator_id]).to be_present
    end

    it "is valid when the same user votes on different posts" do
      other_post = create(:forum_post)
      create(:forum_post_vote, forum_post: post)
      expect(build(:forum_post_vote, forum_post: other_post)).to be_valid
    end

    it "is valid when two different users vote on the same post" do
      create(:forum_post_vote, forum_post: post)
      other_user = create(:user)
      expect(build(:forum_post_vote, forum_post: post, creator: other_user)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited (create only)
  # -------------------------------------------------------------------------
  describe "validate_creator_is_not_limited" do
    let(:voter) { create(:user) }

    it "is valid when the creator is allowed to vote" do
      allow(voter).to receive(:can_forum_vote_with_reason).and_return(true)
      expect(build(:forum_post_vote, creator: voter)).to be_valid
    end

    it "is invalid when the creator is a newbie" do
      allow(voter).to receive(:can_forum_vote_with_reason).and_return(:REJ_NEWBIE)
      record = build(:forum_post_vote, creator: voter)
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "is invalid when the creator has hit the hourly vote limit" do
      allow(voter).to receive(:can_forum_vote_with_reason).and_return(:REJ_LIMITED)
      record = build(:forum_post_vote, creator: voter)
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "does not re-run the throttle check on update" do
      vote = create(:forum_post_vote, creator: voter)
      allow(voter).to receive(:can_forum_vote_with_reason).and_return(:REJ_LIMITED)
      vote.score = -1
      expect(vote).to be_valid
    end
  end
end
