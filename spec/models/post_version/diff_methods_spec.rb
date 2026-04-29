# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  # ------------------------------------------------------------------ #
  # #parent_rating_tags                                                  #
  # ------------------------------------------------------------------ #

  describe "#parent_rating_tags" do
    it "returns just the rating tag when parent_id is nil" do
      pv = build(:post_version, rating: "s")
      pv.parent_id = nil
      expect(pv.parent_rating_tags(pv)).to eq(%w[rating:s])
    end

    it "returns rating and parent tags when parent_id is present" do
      pv = build(:post_version, rating: "e")
      pv.parent_id = 42
      expect(pv.parent_rating_tags(pv)).to eq(%w[rating:e parent:42])
    end
  end

  # ------------------------------------------------------------------ #
  # #diff_sources                                                        #
  # ------------------------------------------------------------------ #

  describe "#diff_sources" do
    it "returns all sources as added when version argument is nil" do
      pv = build(:post_version, source: "https://a.example.com\nhttps://b.example.com")
      result = pv.diff_sources(nil)
      expect(result[:added_sources]).to contain_exactly("https://a.example.com", "https://b.example.com")
      expect(result[:removed_sources]).to be_empty
    end

    it "identifies sources added relative to the given version" do
      old_pv = build(:post_version, source: "https://old.example.com")
      new_pv = build(:post_version, source: "https://old.example.com\nhttps://new.example.com")
      result = new_pv.diff_sources(old_pv)
      expect(result[:added_sources]).to eq(["https://new.example.com"])
    end

    it "identifies sources removed relative to the given version" do
      old_pv = build(:post_version, source: "https://old.example.com\nhttps://gone.example.com")
      new_pv = build(:post_version, source: "https://old.example.com")
      result = new_pv.diff_sources(old_pv)
      expect(result[:removed_sources]).to eq(["https://gone.example.com"])
    end

    it "identifies sources unchanged between versions" do
      old_pv = build(:post_version, source: "https://shared.example.com\nhttps://gone.example.com")
      new_pv = build(:post_version, source: "https://shared.example.com\nhttps://added.example.com")
      result = new_pv.diff_sources(old_pv)
      expect(result[:unchanged_sources]).to eq(["https://shared.example.com"])
    end

    it "handles an empty source string gracefully" do
      old_pv = build(:post_version, source: "https://example.com")
      new_pv = build(:post_version, source: "")
      result = new_pv.diff_sources(old_pv)
      expect(result[:removed_sources]).to eq(["https://example.com"])
      expect(result[:added_sources]).to be_empty
    end
  end

  # ------------------------------------------------------------------ #
  # #diff                                                                #
  # ------------------------------------------------------------------ #

  describe "#diff" do
    it "returns all tags as added when no previous version is given" do
      pv = create(:post_version, tags: "alpha beta")
      result = pv.diff(nil)
      expect(result[:added_tags]).to include("alpha", "beta")
      expect(result[:removed_tags]).to be_empty
    end

    it "identifies tags added relative to the given version" do
      post = create(:post)
      v1   = post.versions.first
      # Manually set v1 tags via update_columns to avoid triggering extra versions
      v1.update_columns(tags: "alpha")
      v2 = create(:post_version, post: post, tags: "alpha beta")
      result = v2.diff(v1)
      expect(result[:added_tags]).to include("beta")
      expect(result[:removed_tags]).not_to include("beta")
    end

    it "identifies tags removed relative to the given version" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(tags: "alpha beta")
      v2 = create(:post_version, post: post, tags: "alpha")
      result = v2.diff(v1)
      expect(result[:removed_tags]).to include("beta")
      expect(result[:added_tags]).not_to include("beta")
    end

    it "identifies unchanged tags" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(tags: "alpha beta")
      v2 = create(:post_version, post: post, tags: "alpha gamma")
      result = v2.diff(v1)
      expect(result[:unchanged_tags]).to include("alpha")
    end

    it "marks an added tag as obsolete when the tag is no longer on the post" do
      # v1: alpha; v2 added 'temporary'; post no longer has 'temporary' now
      post = create(:post)
      v1 = post.versions.first
      v1.update_columns(tags: "alpha", rating: "s")
      v2 = create(:post_version, post: post, tags: "alpha temporary", rating: "s")
      # Strip 'temporary' from the current post state so the added tag is obsolete
      post.update_columns(tag_string: "alpha")
      result = v2.diff(v1)
      expect(result[:obsolete_added_tags]).to include("temporary")
    end

    it "marks a removed tag as obsolete when the tag has returned to the post" do
      # v1: alpha comeback; v2 removed 'comeback'; post has 'comeback' again now
      post = create(:post)
      v1 = post.versions.first
      v1.update_columns(tags: "alpha comeback", rating: "s")
      v2 = create(:post_version, post: post, tags: "alpha", rating: "s")
      # Ensure 'comeback' is back on the current post; reload clears memoized @tag_array
      post.update_columns(tag_string: "alpha comeback")
      post.reload
      result = v2.diff(v1)
      expect(result[:obsolete_removed_tags]).to include("comeback")
    end

    it "computes added and removed locked tags" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(locked_tags: "safe")
      v2 = create(:post_version, post: post, locked_tags: "explicit")
      result = v2.diff(v1)
      expect(result[:added_locked_tags]).to include("explicit")
      expect(result[:removed_locked_tags]).to include("safe")
    end

    it "includes unchanged locked tags" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(locked_tags: "safe meta")
      v2 = create(:post_version, post: post, locked_tags: "safe")
      result = v2.diff(v1)
      expect(result[:unchanged_locked_tags]).to include("safe")
    end
  end

  # ------------------------------------------------------------------ #
  # #changes                                                             #
  # ------------------------------------------------------------------ #

  describe "#changes" do
    it "includes the stored added_tags and removed_tags in the delta" do
      post = create(:post)
      v2 = create(:post_version, post: post, tags: "alpha beta")
      # added_tags and removed_tags are set by fill_changes
      expect(v2.changes[:added_tags]).to include(*v2.added_tags)
    end

    it "appends rating:<value> to added_tags when rating_changed is true" do
      post = create(:post)
      v2 = create(:post_version, post: post, rating: "e")
      # v2 has a different rating than v1, so rating_changed should be true
      v2.update_columns(rating_changed: true)
      v2.instance_variable_set(:@changes, nil) if v2.instance_variable_defined?(:@changes)
      expect(v2.changes[:added_tags]).to include("rating:e")
    end

    it "appends rating of previous to removed_tags when rating_changed and there is a previous version" do
      post = create(:post)
      v1 = post.versions.first
      v1.update_columns(rating: "s")
      v2 = create(:post_version, post: post, rating: "e")
      v2.update_columns(rating_changed: true)
      v2.instance_variable_set(:@changes, nil) if v2.instance_variable_defined?(:@changes)
      expect(v2.changes[:removed_tags]).to include("rating:s")
    end

    it "appends parent:<id> to added_tags when parent_changed and parent_id is present" do
      parent = create(:post)
      post = create(:post)
      v2 = create(:post_version, post: post, parent_id: parent.id)
      v2.update_columns(parent_changed: true)
      v2.instance_variable_set(:@changes, nil) if v2.instance_variable_defined?(:@changes)
      expect(v2.changes[:added_tags]).to include("parent:#{parent.id}")
    end

    it "appends source:<value> to added_tags when source_changed and source is present" do
      post = create(:post)
      v2 = create(:post_version, post: post, source: "https://example.com")
      v2.update_columns(source_changed: true)
      v2.instance_variable_set(:@changes, nil) if v2.instance_variable_defined?(:@changes)
      expect(v2.changes[:added_tags]).to include("source:https://example.com")
    end

    it "returns the delta early without computing obsolete tags when post is nil" do
      pv = create(:post_version)
      pv.post_id = nil # detach post
      allow(pv).to receive(:post).and_return(nil)
      result = pv.changes
      expect(result).to include(:added_tags, :removed_tags)
      expect(result[:obsolete_added_tags]).to eq([])
      expect(result[:obsolete_removed_tags]).to eq([])
    end

    it "memoizes the result" do
      post = create(:post)
      v2   = create(:post_version, post: post)
      first_call  = v2.changes
      second_call = v2.changes
      expect(first_call).to equal(second_call)
    end
  end
end
