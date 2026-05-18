# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ForumTopic Search                                 #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  # Use moderator so .visible doesn't filter out hidden topics in is_hidden tests
  include_context "as moderator"

  let(:category) { create(:forum_category) }

  def make_topic(overrides = {})
    create(:forum_topic, category_id: category.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # title_matches
  # -------------------------------------------------------------------------
  describe "title_matches param" do
    it "filters by exact title" do
      target = make_topic(title: "Exact Title")
      other  = make_topic(title: "Other Title")

      expect(ForumTopic.search(title_matches: "Exact Title")).to include(target)
      expect(ForumTopic.search(title_matches: "Exact Title")).not_to include(other)
    end

    it "supports wildcard suffix matching" do
      alpha = make_topic(title: "Alpha Discussion")
      beta  = make_topic(title: "Beta Discussion")
      other = make_topic(title: "Unrelated")

      result = ForumTopic.search(title_matches: "Alpha*")
      expect(result).to include(alpha)
      expect(result).not_to include(beta, other)
    end
  end

  # -------------------------------------------------------------------------
  # title (exact)
  # -------------------------------------------------------------------------
  describe "title param" do
    it "matches only the exact title" do
      target = make_topic(title: "Exact Match")
      near   = make_topic(title: "Exact Match Extra")

      expect(ForumTopic.search(title: "Exact Match")).to include(target)
      expect(ForumTopic.search(title: "Exact Match")).not_to include(near)
    end
  end

  # -------------------------------------------------------------------------
  # category_id
  # -------------------------------------------------------------------------
  describe "category_id param" do
    it "filters topics by category" do
      other_category = create(:forum_category)
      target = make_topic(category_id: category.id)
      other  = make_topic(category_id: other_category.id)

      expect(ForumTopic.search(category_id: category.id)).to include(target)
      expect(ForumTopic.search(category_id: category.id)).not_to include(other)
    end
  end

  # -------------------------------------------------------------------------
  # Boolean attribute filters
  # -------------------------------------------------------------------------
  describe "is_sticky param" do
    it "filters sticky topics" do
      sticky    = make_topic
      nonsticky = make_topic
      sticky.update_columns(is_sticky: true)
      nonsticky.update_columns(is_sticky: false)

      expect(ForumTopic.search(is_sticky: "true")).to include(sticky)
      expect(ForumTopic.search(is_sticky: "true")).not_to include(nonsticky)
    end
  end

  describe "is_locked param" do
    it "filters locked topics" do
      locked   = make_topic
      unlocked = make_topic
      locked.update_columns(is_locked: true)
      unlocked.update_columns(is_locked: false)

      expect(ForumTopic.search(is_locked: "true")).to include(locked)
      expect(ForumTopic.search(is_locked: "true")).not_to include(unlocked)
    end
  end

  describe "is_hidden param" do
    it "filters hidden topics" do
      hidden  = make_topic
      visible = make_topic
      hidden.update_columns(is_hidden: true)
      visible.update_columns(is_hidden: false)

      expect(ForumTopic.search(is_hidden: "true")).to include(hidden)
      expect(ForumTopic.search(is_hidden: "true")).not_to include(visible)
    end
  end

  # -------------------------------------------------------------------------
  # order
  # -------------------------------------------------------------------------
  describe "order: sticky param" do
    it "places stickied topics before non-stickied" do
      normal = make_topic
      sticky = make_topic
      normal.update_columns(is_sticky: false)
      sticky.update_columns(is_sticky: true)

      ids = ForumTopic.search(order: "sticky").ids
      expect(ids.index(sticky.id)).to be < ids.index(normal.id)
    end
  end
end
