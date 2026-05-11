# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      ForumPostVote Factory Sanity                           #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPostVote do
  include_context "as member"

  describe "factory" do
    it "produces a valid forum_post_vote" do
      expect(create(:forum_post_vote)).to be_persisted
    end

    it "defaults score to 1" do
      expect(create(:forum_post_vote).score).to eq(1)
    end

    it ":down_forum_post_vote has score -1" do
      expect(create(:down_forum_post_vote).score).to eq(-1)
    end

    it ":meh_forum_post_vote has score 0" do
      expect(create(:meh_forum_post_vote).score).to eq(0)
    end
  end
end
