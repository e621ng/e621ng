# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     ForumPostVote Instance Methods                          #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPostVote do
  include_context "as member"

  # -------------------------------------------------------------------------
  # Score predicate methods: #up?, #down?, #meh?, #flip?
  # -------------------------------------------------------------------------
  describe "score predicates" do
    score_kinds = { 1 => :up, -1 => :down, 0 => :meh, 2 => :flip }

    score_kinds.each do |true_score, kind|
      describe "##{kind}?" do
        score_kinds.each_key do |score|
          expected = score == true_score
          it "returns #{expected} for score #{score}" do
            expect(build(:forum_post_vote, score: score).public_send(:"#{kind}?")).to be expected
          end
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # #icon
  # -------------------------------------------------------------------------
  describe "#icon" do
    { 1 => :thumbs_up, -1 => :thumbs_down, 0 => :face_meh, 2 => :refresh }.each do |score, icon|
      it "returns #{icon.inspect} for score #{score}" do
        expect(build(:forum_post_vote, score: score).icon).to eq(icon)
      end
    end

    it "returns :flame for an unrecognized score" do
      vote = build(:forum_post_vote)
      vote.score = 99
      expect(vote.icon).to eq(:flame)
    end
  end

  # -------------------------------------------------------------------------
  # #vote_type
  # -------------------------------------------------------------------------
  describe "#vote_type" do
    { 1 => "up", -1 => "down", 0 => "meh", 2 => "flip" }.each do |score, type|
      it "returns #{type.inspect} for score #{score}" do
        expect(build(:forum_post_vote, score: score).vote_type).to eq(type)
      end
    end

    it "returns 'unknown' for an unrecognized score" do
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
