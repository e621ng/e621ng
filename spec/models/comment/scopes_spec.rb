# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Comment Scopes                                     #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  include_context "as member"

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let!(:visible_comment) { create(:comment, is_hidden: false) }
  let!(:hidden_comment)  { create(:comment, is_hidden: true) }
  let!(:sticky_comment)  { create(:comment, is_sticky: true) }

  # -------------------------------------------------------------------------
  # .deleted
  # -------------------------------------------------------------------------
  describe ".deleted" do
    it "includes comments with is_hidden: true" do
      expect(Comment.deleted).to include(hidden_comment)
    end

    it "excludes comments with is_hidden: false" do
      expect(Comment.deleted).not_to include(visible_comment)
    end
  end

  # -------------------------------------------------------------------------
  # .undeleted
  # -------------------------------------------------------------------------
  describe ".undeleted" do
    it "includes comments with is_hidden: false" do
      expect(Comment.undeleted).to include(visible_comment)
    end

    it "excludes comments with is_hidden: true" do
      expect(Comment.undeleted).not_to include(hidden_comment)
    end
  end

  # -------------------------------------------------------------------------
  # .stickied
  # -------------------------------------------------------------------------
  describe ".stickied" do
    it "includes comments with is_sticky: true" do
      expect(Comment.stickied).to include(sticky_comment)
    end

    it "excludes comments with is_sticky: false" do
      expect(Comment.stickied).not_to include(visible_comment)
    end
  end

  # -------------------------------------------------------------------------
  # .for_creator
  # -------------------------------------------------------------------------
  describe ".for_creator" do
    it "returns comments created by the given user id" do
      expect(Comment.for_creator(visible_comment.creator_id)).to include(visible_comment)
    end

    it "returns none when user_id is nil" do
      expect(Comment.for_creator(nil)).to eq(Comment.none)
    end

    it "returns none when user_id is blank" do
      expect(Comment.for_creator("")).to eq(Comment.none)
    end
  end

  # -------------------------------------------------------------------------
  # .recent
  # -------------------------------------------------------------------------
  describe ".recent" do
    it "returns at most RECENT_COUNT records" do
      (Comment::RECENT_COUNT + 2).times { create(:comment) }
      expect(Comment.recent.count).to eq(Comment::RECENT_COUNT)
    end

    it "returns records in descending id order" do
      ids = Comment.recent.map(&:id)
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
