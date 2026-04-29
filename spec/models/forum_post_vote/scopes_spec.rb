# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ForumPostVote Scopes                               #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPostVote do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:user_c) { create(:user) }

  before do
    CurrentUser.user    = user_a
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # -------------------------------------------------------------------------
  # .up
  # -------------------------------------------------------------------------
  describe ".up" do
    let!(:up_vote)   { create(:forum_post_vote, creator: user_a, score: 1) }
    let!(:down_vote) { create(:forum_post_vote, creator: user_b, score: -1) }
    let!(:meh_vote)  { create(:forum_post_vote, creator: user_c, score: 0) }

    it "returns votes with score 1" do
      expect(ForumPostVote.up).to include(up_vote)
    end

    it "excludes votes with score -1" do
      expect(ForumPostVote.up).not_to include(down_vote)
    end

    it "excludes votes with score 0" do
      expect(ForumPostVote.up).not_to include(meh_vote)
    end
  end

  # -------------------------------------------------------------------------
  # .down
  # -------------------------------------------------------------------------
  describe ".down" do
    let!(:up_vote)   { create(:forum_post_vote, creator: user_a, score: 1) }
    let!(:down_vote) { create(:forum_post_vote, creator: user_b, score: -1) }
    let!(:meh_vote)  { create(:forum_post_vote, creator: user_c, score: 0) }

    it "returns votes with score -1" do
      expect(ForumPostVote.down).to include(down_vote)
    end

    it "excludes votes with score 1" do
      expect(ForumPostVote.down).not_to include(up_vote)
    end

    it "excludes votes with score 0" do
      expect(ForumPostVote.down).not_to include(meh_vote)
    end
  end

  # -------------------------------------------------------------------------
  # .by
  # -------------------------------------------------------------------------
  describe ".by" do
    let!(:vote_by_a) { create(:forum_post_vote, creator: user_a) }
    let!(:vote_by_b) { create(:forum_post_vote, creator: user_b) }

    it "returns votes created by the specified user" do
      expect(ForumPostVote.by(user_a.id)).to include(vote_by_a)
    end

    it "excludes votes from other users" do
      expect(ForumPostVote.by(user_a.id)).not_to include(vote_by_b)
    end
  end

  # -------------------------------------------------------------------------
  # .excluding_user
  # -------------------------------------------------------------------------
  describe ".excluding_user" do
    let!(:vote_by_a) { create(:forum_post_vote, creator: user_a) }
    let!(:vote_by_b) { create(:forum_post_vote, creator: user_b) }

    it "excludes votes by the specified user" do
      expect(ForumPostVote.excluding_user(user_a.id)).not_to include(vote_by_a)
    end

    it "includes votes from other users" do
      expect(ForumPostVote.excluding_user(user_a.id)).to include(vote_by_b)
    end
  end
end
