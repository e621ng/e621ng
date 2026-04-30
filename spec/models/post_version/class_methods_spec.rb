# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  # ------------------------------------------------------------------ #
  # .calculate_version                                                   #
  # ------------------------------------------------------------------ #

  describe ".calculate_version" do
    it "returns 1 when the post has no existing versions" do
      post = create(:post)
      post.versions.destroy_all
      expect(PostVersion.calculate_version(post.id)).to eq(1)
    end

    it "returns max_version + 1 when versions already exist" do
      post = create(:post)
      # post now has version 1 from its after_save callback
      expect(PostVersion.calculate_version(post.id)).to eq(2)
    end

    it "returns the correct next version after multiple versions" do
      post = create(:post)
      create(:post_version, post: post) # version 2
      create(:post_version, post: post) # version 3
      expect(PostVersion.calculate_version(post.id)).to eq(4)
    end
  end

  # ------------------------------------------------------------------ #
  # .queue                                                               #
  # ------------------------------------------------------------------ #

  describe ".queue" do
    it "creates a new PostVersion record" do
      post = create(:post)
      expect { PostVersion.queue(post) }.to change(PostVersion, :count).by(1)
    end

    it "copies the post rating onto the new version" do
      post = create(:post, rating: "e")
      pv   = PostVersion.queue(post)
      expect(pv.rating).to eq("e")
    end

    it "copies the post source onto the new version" do
      post = create(:post, source: "https://example.com")
      pv   = PostVersion.queue(post)
      expect(pv.source).to eq("https://example.com")
    end

    it "copies the post tag_string onto the new version" do
      post = create(:post)
      pv   = PostVersion.queue(post)
      expect(pv.tags).to eq(post.tag_string)
    end

    it "copies description onto the new version" do
      post = create(:post, description: "test description")
      pv   = PostVersion.queue(post)
      expect(pv.description).to eq("test description")
    end

    it "copies locked_tags onto the new version" do
      post = create(:post)
      post.update_columns(locked_tags: "tagme")
      pv = PostVersion.queue(post)
      expect(pv.locked_tags).to eq("tagme")
    end

    it "copies edit_reason onto the new version as reason" do
      post = create(:post)
      post.edit_reason = "fixing tags"
      pv = PostVersion.queue(post)
      expect(pv.reason).to eq("fixing tags")
    end

    it "sets updater_id to CurrentUser.id" do
      post = create(:post)
      pv   = PostVersion.queue(post)
      expect(pv.updater_id).to eq(CurrentUser.id)
    end

    it "sets updater_ip_addr to CurrentUser.ip_addr" do
      post = create(:post)
      pv   = PostVersion.queue(post)
      expect(pv.updater_ip_addr.to_s).to eq(CurrentUser.ip_addr)
    end
  end
end
