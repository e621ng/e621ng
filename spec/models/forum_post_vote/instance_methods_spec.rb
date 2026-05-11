# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     ForumPostVote Instance Methods                          #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPostVote do
  include_context "as member"

  # -------------------------------------------------------------------------
  # #up?
  # -------------------------------------------------------------------------
  describe "#up?" do
    it "returns true for score 1" do
      expect(build(:forum_post_vote, score: 1).up?).to be true
    end

    it "returns false for score -1" do
      expect(build(:forum_post_vote, score: -1).up?).to be false
    end

    it "returns false for score 0" do
      expect(build(:forum_post_vote, score: 0).up?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #down?
  # -------------------------------------------------------------------------
  describe "#down?" do
    it "returns true for score -1" do
      expect(build(:forum_post_vote, score: -1).down?).to be true
    end

    it "returns false for score 1" do
      expect(build(:forum_post_vote, score: 1).down?).to be false
    end

    it "returns false for score 0" do
      expect(build(:forum_post_vote, score: 0).down?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #meh?
  # -------------------------------------------------------------------------
  describe "#meh?" do
    it "returns true for score 0" do
      expect(build(:forum_post_vote, score: 0).meh?).to be true
    end

    it "returns false for score 1" do
      expect(build(:forum_post_vote, score: 1).meh?).to be false
    end

    it "returns false for score -1" do
      expect(build(:forum_post_vote, score: -1).meh?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #icon
  # -------------------------------------------------------------------------
  describe "#icon" do
    it "returns :thumbs_up for score 1" do
      expect(build(:forum_post_vote, score: 1).icon).to eq(:thumbs_up)
    end

    it "returns :thumbs_down for score -1" do
      expect(build(:forum_post_vote, score: -1).icon).to eq(:thumbs_down)
    end

    it "returns :face_meh for score 0" do
      expect(build(:forum_post_vote, score: 0).icon).to eq(:face_meh)
    end

    it "returns fallback for an unexpected score value" do
      vote = build(:forum_post_vote)
      vote.score = 99
      expect(vote.icon).to eq(:flame)
    end
  end

  # -------------------------------------------------------------------------
  # #vote_type
  # -------------------------------------------------------------------------
  describe "#vote_type" do
    it "returns 'up' for score 1" do
      expect(build(:forum_post_vote, score: 1).vote_type).to eq("up")
    end

    it "returns 'down' for score -1" do
      expect(build(:forum_post_vote, score: -1).vote_type).to eq("down")
    end

    it "returns 'meh' for score 0" do
      expect(build(:forum_post_vote, score: 0).vote_type).to eq("meh")
    end

    it "returns 'unknown' for an unexpected score value" do
      vote = build(:forum_post_vote)
      vote.score = 99
      expect(vote.vote_type).to eq("unknown")
    end
  end

  # -------------------------------------------------------------------------
  # #creator_name
  # -------------------------------------------------------------------------
  describe "#creator_name" do
    it "returns the creator's username" do
      vote = create(:forum_post_vote)
      expect(vote.creator_name).to eq(vote.creator.name)
    end
  end
end
