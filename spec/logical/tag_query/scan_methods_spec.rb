# frozen_string_literal: true

require "rails_helper"

# Tests public class-level utility / scanning methods:
#   TagQuery.normalize        — normalise a flat query string
#   TagQuery.normalize_search — normalise while honouring group structure
#   TagQuery.fetch_metatag    — extract first matching metatag value from a string
#   TagQuery.has_metatag?     — check presence of a metatag in a string
#   TagQuery.fetch_metatags   — extract all matching metatag values as a hash
#   TagQuery.has_tag?         — check whether a tag is present in a token array

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe ".normalize" do
    it "downcases and sorts tokens alphabetically" do
      result = TagQuery.normalize("Tag_B Tag_A")
      expect(result).to eq("tag_a tag_b")
    end

    it "removes duplicate tokens" do
      result = TagQuery.normalize("solo solo")
      expect(result).to eq("solo")
    end

    it "resolves tag aliases" do
      create(:active_tag_alias, antecedent_name: "old_tag", consequent_name: "new_tag")
      result = TagQuery.normalize("old_tag")
      expect(result).to include("new_tag")
      expect(result).not_to include("old_tag")
    end

    it "returns an empty string for a blank input" do
      expect(TagQuery.normalize("")).to eq("")
      expect(TagQuery.normalize("   ")).to eq("")
    end
  end

  describe ".normalize_search" do
    it "sorts tokens within a flat query" do
      result = TagQuery.normalize_search("tag_b tag_a")
      expect(result).to eq("tag_a tag_b")
    end

    it "preserves group delimiters while normalising content" do
      result = TagQuery.normalize_search("( tag_b tag_a )")
      expect(result).to include("tag_a")
      expect(result).to include("tag_b")
      expect(result).to include("(")
      expect(result).to include(")")
    end

    it "removes duplicate tokens within each group level" do
      result = TagQuery.normalize_search("solo solo")
      expect(result).to eq("solo")
    end
  end

  describe ".fetch_metatag" do
    it "returns the value of the first matching metatag" do
      expect(TagQuery.fetch_metatag("order:score tag1", "order")).to eq("score")
    end

    it "returns nil when the metatag is not present" do
      expect(TagQuery.fetch_metatag("tag1 tag2", "order")).to be_nil
    end

    it "returns nil for a blank query" do
      expect(TagQuery.fetch_metatag("", "order")).to be_nil
    end

    it "strips surrounding quotes from quoted metatag values" do
      expect(TagQuery.fetch_metatag('description:"hello world" tag1', "description")).to eq("hello world")
    end

    it "searches inside groups by default (at_any_level: true)" do
      expect(TagQuery.fetch_metatag("( order:score tag1 )", "order")).to eq("score")
    end

    # NOTE: fetch_metatag returns inconsistent results.
    # * at_any_level: true, not found → scan_metatags returns nil (its initial_value default)
    # * at_any_level: false, not found → match_tokens returns [] (its results array)
    it "does not search inside groups when at_any_level: false" do
      expect(TagQuery.fetch_metatag("( order:score )", "order", at_any_level: false)).to be_blank
    end
  end

  describe ".has_metatag?" do
    it "returns true when the metatag is present" do
      expect(TagQuery.has_metatag?("order:score tag1", "order")).to be(true)
    end

    it "returns false when the metatag is absent" do
      expect(TagQuery.has_metatag?("tag1 tag2", "order")).to be(false)
    end

    it "accepts multiple metatag names and returns true if any match" do
      expect(TagQuery.has_metatag?("status:pending", "order", "status")).to be(true)
    end
  end

  describe ".fetch_metatags" do
    it "returns a hash of metatag name to array of values" do
      result = TagQuery.fetch_metatags("order:score status:pending", "order", "status")
      expect(result["order"]).to eq(["score"])
      expect(result["status"]).to eq(["pending"])
    end

    it "returns an empty hash when no metatags are found" do
      result = TagQuery.fetch_metatags("tag1 tag2", "order")
      expect(result).to eq({})
    end

    it "collects multiple values for a repeated metatag" do
      result = TagQuery.fetch_metatags("rating:s rating:e", "rating")
      expect(result["rating"]).to include("s", "e")
    end

    it "returns an empty hash for a blank query" do
      expect(TagQuery.fetch_metatags("", "order")).to eq({})
    end
  end

  describe ".has_tag?" do
    it "returns true when a tag is found in the array" do
      expect(TagQuery.has_tag?(%w[tag_a tag_b], "tag_a")).to be(true)
    end

    it "returns false when the tag is absent from the array" do
      expect(TagQuery.has_tag?(%w[tag_a tag_b], "tag_c")).to be(false)
    end

    it "accepts multiple tags to find and returns true if any match" do
      expect(TagQuery.has_tag?(["tag_a"], "tag_x", "tag_a")).to be(true)
    end

    it "returns false for an empty array" do
      expect(TagQuery.has_tag?([], "tag_a")).to be(false)
    end
  end
end
