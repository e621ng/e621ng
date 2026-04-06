# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ForumPost Search                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  include_context "as member"

  let(:category) { create(:forum_category) }
  let(:topic)    { create(:forum_topic, category_id: category.id) }
  let(:other_topic) { create(:forum_topic) }

  def make_post(overrides = {})
    create(:forum_post, topic_id: topic.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # creator_id / creator param
  # -------------------------------------------------------------------------
  describe "creator_id param" do
    it "returns only posts by the given creator" do
      creator = create(:user)
      post    = make_post
      post.update_columns(creator_id: creator.id)
      other_post = make_post

      result = ForumPost.search(creator_id: creator.id.to_s)
      expect(result).to include(post)
      expect(result).not_to include(other_post)
    end
  end

  # -------------------------------------------------------------------------
  # topic_id param
  # -------------------------------------------------------------------------
  describe "topic_id param" do
    it "returns only posts in the specified topic" do
      post       = make_post
      other_post = create(:forum_post, topic_id: other_topic.id)

      result = ForumPost.search(topic_id: topic.id.to_s)
      expect(result).to include(post)
      expect(result).not_to include(other_post)
    end
  end

  # -------------------------------------------------------------------------
  # topic_title_matches param
  # -------------------------------------------------------------------------
  describe "topic_title_matches param" do
    it "returns posts whose parent topic title matches exactly" do
      topic.update_columns(title: "unique_title_for_search_#{topic.id}")
      post       = make_post
      other_post = create(:forum_post, topic_id: other_topic.id)

      result = ForumPost.search(topic_title_matches: topic.reload.title)
      expect(result).to include(post)
      expect(result).not_to include(other_post)
    end

    it "supports a trailing wildcard" do
      post  = make_post
      title = topic.title
      topic.update_columns(title: "#{title}_unique_prefix_xyz")
      other_post = create(:forum_post, topic_id: other_topic.id)

      result = ForumPost.search(topic_title_matches: "#{title}_unique_prefix_*")
      expect(result).to include(post)
      expect(result).not_to include(other_post)
    end
  end

  # -------------------------------------------------------------------------
  # body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns posts whose body contains the search term" do
      matching = make_post(body: "contains the word banana in it")
      other    = make_post(body: "contains nothing special")

      result = ForumPost.search(body_matches: "banana")
      expect(result).to include(matching)
      expect(result).not_to include(other)
    end
  end

  # -------------------------------------------------------------------------
  # topic_category_id param
  # -------------------------------------------------------------------------
  describe "topic_category_id param" do
    it "returns only posts in topics belonging to the given category" do
      post       = make_post
      other_post = create(:forum_post, topic_id: other_topic.id)

      result = ForumPost.search(topic_category_id: category.id.to_s)
      expect(result).to include(post)
      expect(result).not_to include(other_post)
    end
  end

  # -------------------------------------------------------------------------
  # is_hidden param
  # -------------------------------------------------------------------------
  describe "is_hidden param" do
    it "returns only hidden posts when is_hidden is true" do
      hidden  = make_post
      visible = make_post
      hidden.update_columns(is_hidden: true)

      result = ForumPost.search(is_hidden: "true")
      expect(result).to include(hidden)
      expect(result).not_to include(visible)
    end

    it "returns only visible posts when is_hidden is false" do
      hidden  = make_post
      visible = make_post
      hidden.update_columns(is_hidden: true)

      result = ForumPost.search(is_hidden: "false")
      expect(result).to include(visible)
      expect(result).not_to include(hidden)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "returns posts newest-first by default" do
      older = make_post
      newer = make_post
      older.update_columns(created_at: 1.hour.ago)

      ids = ForumPost.where(topic_id: topic.id).search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
