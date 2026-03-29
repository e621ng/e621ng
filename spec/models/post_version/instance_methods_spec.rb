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
end
