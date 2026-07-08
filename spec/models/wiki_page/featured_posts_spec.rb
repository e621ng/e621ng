# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        WikiPage Featured Posts                              #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # Attribute parsing (via array_attribute)
  # -------------------------------------------------------------------------
  describe "#featured_posts_string=" do
    it "parses a space-separated string into an array of integer IDs" do
      page = build(:wiki_page)
      page.featured_posts_string = "123 456"
      expect(page.featured_posts).to eq([123, 456])
    end

    it "ignores non-numeric noise" do
      page = build(:wiki_page)
      page.featured_posts_string = "123, #456 foo"
      expect(page.featured_posts).to eq([123, 456])
    end
  end

  describe "#featured_posts=" do
    it "accepts an array directly" do
      page = build(:wiki_page)
      page.featured_posts = [1, 2, 3]
      expect(page.featured_posts).to eq([1, 2, 3])
    end
  end

  # -------------------------------------------------------------------------
  # Validation
  # -------------------------------------------------------------------------
  describe "featured_posts validation" do
    it "accepts a valid list of existing post IDs" do
      posts = create_list(:post, 2)
      page = build(:wiki_page, featured_posts: posts.map(&:id))
      expect(page).to be_valid
    end

    it "accepts a post that has been deleted" do
      post = create(:post)
      post.update_column(:is_deleted, true)
      page = build(:wiki_page, featured_posts: [post.id])
      expect(page).to be_valid
    end

    it "rejects more than the configured maximum" do
      posts = create_list(:post, Danbooru.config.wiki_page_max_featured_posts + 1)
      page = build(:wiki_page, featured_posts: posts.map(&:id))
      expect(page).not_to be_valid
      expect(page.errors[:featured_posts]).to be_present
    end

    it "rejects duplicate post IDs" do
      post = create(:post)
      page = build(:wiki_page, featured_posts: [post.id, post.id])
      expect(page).not_to be_valid
      expect(page.errors[:featured_posts]).to be_present
    end

    it "rejects nonexistent post IDs" do
      page = build(:wiki_page, featured_posts: [999_999])
      expect(page).not_to be_valid
      expect(page.errors[:featured_posts]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # Versioning
  # -------------------------------------------------------------------------
  describe "versioning" do
    it "records featured_posts in a new version when changed" do
      posts = create_list(:post, 2)
      page = create(:wiki_page)
      expect do
        page.update(featured_posts: posts.map(&:id))
      end.to change { page.versions.count }.by(1)
      expect(page.versions.last.featured_posts).to eq(posts.map(&:id))
    end

    it "restores featured_posts on revert" do
      posts = create_list(:post, 2)
      page = create(:wiki_page, featured_posts: [posts.first.id])
      original_version = page.versions.last

      page.update(featured_posts: posts.map(&:id))
      page.revert_to!(original_version)

      expect(page.reload.featured_posts).to eq([posts.first.id])
    end
  end
end
