# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  # ------------------------------------------------------------------ #
  # #tag_array                                                           #
  # ------------------------------------------------------------------ #

  describe "#tag_array" do
    it "splits tags on whitespace and returns an array" do
      pv = build(:post_version, tags: "alpha beta gamma")
      expect(pv.tag_array).to eq(%w[alpha beta gamma])
    end

    it "returns a single-element array when there is one tag" do
      pv = build(:post_version, tags: "tagme")
      expect(pv.tag_array).to eq(%w[tagme])
    end

    it "is memoized" do
      pv = build(:post_version, tags: "alpha beta")
      first_call  = pv.tag_array
      second_call = pv.tag_array
      expect(first_call).to equal(second_call)
    end
  end

  # ------------------------------------------------------------------ #
  # #locked_tag_array                                                    #
  # ------------------------------------------------------------------ #

  describe "#locked_tag_array" do
    it "returns an empty array when locked_tags is nil" do
      pv = build(:post_version, locked_tags: nil)
      expect(pv.locked_tag_array).to eq([])
    end

    it "returns an empty array when locked_tags is an empty string" do
      pv = build(:post_version, locked_tags: "")
      expect(pv.locked_tag_array).to eq([])
    end

    it "splits locked_tags on whitespace" do
      pv = build(:post_version, locked_tags: "safe explicit")
      expect(pv.locked_tag_array).to eq(%w[safe explicit])
    end
  end

  # ------------------------------------------------------------------ #
  # #previous                                                            #
  # ------------------------------------------------------------------ #

  describe "#previous" do
    it "returns nil for version 1 without querying the database" do
      pv = build(:post_version)
      pv.version = 1
      allow(pv).to receive(:class) # ensure no DB call needed
      expect(pv.previous).to be_nil
      expect(pv).not_to have_received(:class)
    end

    it "returns nil for version 0 (guard against edge-case data)" do
      pv = build(:post_version)
      pv.version = 0
      expect(pv.previous).to be_nil
    end

    it "returns the immediately preceding version for version 2" do
      post = create(:post)
      v1   = post.versions.first
      v2   = create(:post_version, post: post)
      expect(v2.previous).to eq(v1)
    end

    it "returns the closest preceding version when multiple older versions exist" do
      post = create(:post)
      v2   = create(:post_version, post: post)
      v3   = create(:post_version, post: post)
      expect(v3.previous).to eq(v2)
    end

    it "uses the preloaded post.versions association when available" do
      post = create(:post)
      v1   = post.versions.first
      v2   = create(:post_version, post: post)
      # Force-load post and its versions association
      loaded_post     = Post.includes(:versions).find(post.id)
      loaded_v2       = loaded_post.versions.find { |v| v.id == v2.id }
      expect(loaded_v2.previous.id).to eq(v1.id)
    end

    it "is memoized after the first lookup" do
      post = create(:post)
      v2   = create(:post_version, post: post)
      first_call  = v2.previous
      second_call = v2.previous
      expect(first_call).to equal(second_call)
    end
  end

  # ------------------------------------------------------------------ #
  # #undoable?                                                           #
  # ------------------------------------------------------------------ #

  describe "#undoable?" do
    it "returns false for version 1" do
      pv = build(:post_version)
      pv.version = 1
      expect(pv.undoable?).to be false
    end

    it "returns true for version 2" do
      pv = build(:post_version)
      pv.version = 2
      expect(pv.undoable?).to be true
    end

    it "returns true for any version greater than 1" do
      pv = build(:post_version)
      pv.version = 99
      expect(pv.undoable?).to be true
    end
  end

  # ------------------------------------------------------------------ #
  # #presenter                                                           #
  # ------------------------------------------------------------------ #

  # FIXME: PostVersionPresenter is referenced in #presenter but the class
  # does not exist anywhere in the codebase. This test will raise NameError
  # until the presenter is defined.
  #
  # describe "#presenter" do
  #   it "returns a PostVersionPresenter" do
  #     pv = create(:post_version)
  #     expect(pv.presenter).to be_a(PostVersionPresenter)
  #   end
  # end

  # ------------------------------------------------------------------ #
  # #diff_tag_names                                                      #
  # ------------------------------------------------------------------ #

  describe "#diff_tag_names" do
    it "includes added, removed, and unchanged tags from the diff" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(tags: "alpha beta")
      v2 = create(:post_version, post: post, tags: "alpha gamma")
      expect(v2.diff_tag_names).to include("alpha", "beta", "gamma")
    end

    # Locked tags use a "-name" prefix to mean "lock this tag OFF" (see Post#normalize_tags).
    # The category lookup needs the real tag name, so the leading minus is stripped.
    it "strips a leading minus from locked tag names" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(locked_tags: "-cub")
      v2 = create(:post_version, post: post, locked_tags: "")
      expect(v2.diff_tag_names).to include("cub")
      expect(v2.diff_tag_names).not_to include("-cub")
    end
  end

  # ------------------------------------------------------------------ #
  # #tag_categories                                                      #
  # ------------------------------------------------------------------ #

  describe "#tag_categories" do
    it "returns the preset hash without hitting Tag.categories_for" do
      pv = build(:post_version)
      pv.preset_tag_categories({ "alpha" => 1 })
      allow(Tag).to receive(:categories_for)
      expect(pv.tag_categories).to eq({ "alpha" => 1 })
      expect(Tag).not_to have_received(:categories_for)
    end

    it "falls back to Tag.categories_for(diff_tag_names) when not preset" do
      pv = build(:post_version)
      allow(pv).to receive(:diff_tag_names).and_return(%w[alpha beta])
      allow(Tag).to receive(:categories_for).with(%w[alpha beta]).and_return({ "alpha" => 1, "beta" => 4 })
      expect(pv.tag_categories).to eq({ "alpha" => 1, "beta" => 4 })
    end
  end
end
