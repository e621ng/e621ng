# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  # Helper: build a second PostVersion for the same post with different attributes.
  def make_second_version(post, overrides = {})
    create(:post_version, { post: post, tags: "foo bar", rating: "s", source: "", description: "", parent_id: nil }.merge(overrides))
  end

  # ------------------------------------------------------------------ #
  # fill_version                                                         #
  # ------------------------------------------------------------------ #

  describe "fill_version" do
    it "sets version to 1 for the first PostVersion of a post" do
      post = create(:post)
      # Destroy the auto-created version so we can create one manually.
      post.versions.destroy_all
      pv = create(:post_version, post: post)
      expect(pv.version).to eq(1)
    end

    it "sets version to 2 for the second PostVersion of a post" do
      post = create(:post)
      # post already has version 1 from its after_save callback
      second = create(:post_version, post: post)
      expect(second.version).to eq(2)
    end

    it "increments version by 1 for each additional PostVersion" do
      post = create(:post)
      create(:post_version, post: post)
      third = create(:post_version, post: post)
      expect(third.version).to eq(3)
    end
  end

  # ------------------------------------------------------------------ #
  # fill_changes                                                         #
  # ------------------------------------------------------------------ #

  describe "fill_changes" do
    describe "first version (no previous)" do
      it "sets added_tags equal to the full tag array" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post, tags: "alpha beta")
        expect(pv.added_tags).to match_array(%w[alpha beta])
      end

      it "sets removed_tags to an empty array" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post, tags: "alpha beta")
        expect(pv.removed_tags).to be_empty
      end

      it "sets rating_changed to true" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post)
        expect(pv.rating_changed).to be true
      end

      it "sets parent_changed to true" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post)
        expect(pv.parent_changed).to be true
      end

      it "sets source_changed to true" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post)
        expect(pv.source_changed).to be true
      end

      it "sets description_changed to true" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post)
        expect(pv.description_changed).to be true
      end
    end

    describe "second version (has previous)" do
      it "sets added_tags to tags present in v2 but not v1" do
        post = create(:post)
        create(:post_version, post: post, tags: "alpha")
        second = create(:post_version, post: post, tags: "alpha beta")
        expect(second.added_tags).to match_array(%w[beta])
      end

      it "sets removed_tags to tags present in v1 but not v2" do
        post = create(:post)
        create(:post_version, post: post, tags: "alpha beta")
        second = create(:post_version, post: post, tags: "alpha")
        expect(second.removed_tags).to match_array(%w[beta])
      end

      it "sets rating_changed to false when rating is unchanged" do
        post = create(:post)
        create(:post_version, post: post, rating: "s")
        second = create(:post_version, post: post, rating: "s")
        expect(second.rating_changed).to be false
      end

      it "sets rating_changed to true when rating differs from previous" do
        post = create(:post)
        create(:post_version, post: post, rating: "s")
        second = create(:post_version, post: post, rating: "e")
        expect(second.rating_changed).to be true
      end

      it "sets parent_changed to false when parent_id is unchanged" do
        parent = create(:post)
        post   = create(:post)
        create(:post_version, post: post, parent_id: parent.id)
        second = create(:post_version, post: post, parent_id: parent.id)
        expect(second.parent_changed).to be false
      end

      it "sets parent_changed to true when parent_id differs from previous" do
        parent_a = create(:post)
        parent_b = create(:post)
        post     = create(:post)
        create(:post_version, post: post, parent_id: parent_a.id)
        second = create(:post_version, post: post, parent_id: parent_b.id)
        expect(second.parent_changed).to be true
      end

      it "sets source_changed to false when source is unchanged" do
        post = create(:post)
        create(:post_version, post: post, source: "https://example.com")
        second = create(:post_version, post: post, source: "https://example.com")
        expect(second.source_changed).to be false
      end

      it "sets source_changed to true when source differs from previous" do
        post = create(:post)
        create(:post_version, post: post, source: "https://old.example.com")
        second = create(:post_version, post: post, source: "https://new.example.com")
        expect(second.source_changed).to be true
      end

      it "sets description_changed to false when description is unchanged" do
        post = create(:post)
        create(:post_version, post: post, description: "same text")
        second = create(:post_version, post: post, description: "same text")
        expect(second.description_changed).to be false
      end

      it "sets description_changed to true when description differs from previous" do
        post = create(:post)
        create(:post_version, post: post, description: "original")
        second = create(:post_version, post: post, description: "updated")
        expect(second.description_changed).to be true
      end
    end

    describe "locked tags" do
      it "sets added_locked_tags on the first version" do
        post = create(:post)
        post.versions.destroy_all
        pv = create(:post_version, post: post, locked_tags: "safe")
        expect(pv.added_locked_tags).to include("safe")
      end

      it "sets removed_locked_tags when a locked tag is dropped" do
        post = create(:post)
        create(:post_version, post: post, locked_tags: "safe explicit")
        second = create(:post_version, post: post, locked_tags: "safe")
        expect(second.removed_locked_tags).to include("explicit")
      end
    end
  end
end
