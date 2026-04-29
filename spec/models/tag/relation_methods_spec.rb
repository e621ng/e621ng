# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Tag::RelationMethods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #related_cache_expiry
  # -------------------------------------------------------------------------
  describe "#related_cache_expiry" do
    it "returns the floor (24) when post_count is 0" do
      tag = build(:tag, post_count: 0)
      expect(tag.related_cache_expiry).to eq(24)
    end

    it "returns the floor (24) when sqrt(post_count) is below 24" do
      # sqrt(100) = 10, below floor of 24
      tag = build(:tag, post_count: 100)
      expect(tag.related_cache_expiry).to eq(24)
    end

    it "returns the ceiling (24 * 30 = 720) when post_count is very large" do
      # sqrt(1_000_000) = 1000, above ceiling of 720
      tag = build(:tag, post_count: 1_000_000)
      expect(tag.related_cache_expiry).to eq(24 * 30)
    end

    it "returns Math.sqrt(post_count) in the mid range" do
      # sqrt(2500) = 50, between 24 and 720
      tag = build(:tag, post_count: 2_500)
      expect(tag.related_cache_expiry).to be_within(0.001).of(Math.sqrt(2_500))
    end
  end

  # -------------------------------------------------------------------------
  # #should_update_related?
  # -------------------------------------------------------------------------
  describe "#should_update_related?" do
    it "returns true when related_tags is blank" do
      tag = build(:tag, related_tags: nil, related_tags_updated_at: Time.now)
      expect(tag.should_update_related?).to be true
    end

    it "returns true when related_tags_updated_at is blank" do
      tag = build(:tag, related_tags: "some_tag 1.0", related_tags_updated_at: nil)
      expect(tag.should_update_related?).to be true
    end

    it "returns true when related_tags_updated_at is older than related_cache_expiry hours ago" do
      tag = build(:tag, post_count: 0, related_tags: "some_tag 1.0",
                        related_tags_updated_at: 25.hours.ago)
      # cache expiry is 24h for post_count 0, so 25h ago is stale
      expect(tag.should_update_related?).to be true
    end

    it "returns false when related_tags was recently updated" do
      tag = build(:tag, post_count: 0, related_tags: "some_tag 1.0",
                        related_tags_updated_at: 1.hour.ago)
      expect(tag.should_update_related?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #related_tag_array
  # -------------------------------------------------------------------------
  describe "#related_tag_array" do
    it "returns an array of [name, score] pairs from related_tags" do
      tag = build(:tag, related_tags: "foo 0.8 bar 0.5", related_tags_updated_at: 1.hour.ago,
                        post_count: 0)
      allow(tag).to receive(:update_related_if_outdated)
      result = tag.related_tag_array
      expect(result).to eq([["foo", "0.8"], ["bar", "0.5"]])
    end

    it "returns an empty array when related_tags is blank" do
      tag = build(:tag, related_tags: nil, related_tags_updated_at: 1.hour.ago, post_count: 0)
      allow(tag).to receive(:update_related_if_outdated)
      expect(tag.related_tag_array).to eq([])
    end

    it "calls update_related_if_outdated" do
      tag = build(:tag, related_tags: "foo 0.8", related_tags_updated_at: 1.hour.ago, post_count: 0)
      allow(tag).to receive(:update_related_if_outdated)
      tag.related_tag_array
      expect(tag).to have_received(:update_related_if_outdated)
    end
  end
end
