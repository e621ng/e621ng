# frozen_string_literal: true

require "rails_helper"

# Tests the three TagQuery exception classes: CountExceededError, DepthExceededError,
# and InvalidTagError.
#
# CountExceededError  — raised when the parsed tag count exceeds tag_query_limit.
# DepthExceededError  — raised when group nesting exceeds DEPTH_LIMIT (10).
# InvalidTagError     — tested via direct instantiation; not raised in the default
#                       configuration because SETTINGS[:CHECK_TAG_VALIDITY] is false.

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe TagQuery::CountExceededError do
    it "is a StandardError" do
      expect(TagQuery::CountExceededError.new).to be_a(StandardError)
    end

    it "exposes query_obj, tag_count, and free_tags_count attributes" do
      tq    = instance_double(TagQuery)
      error = TagQuery::CountExceededError.new(
        "too many tags",
        query_obj:       tq,
        tag_count:       10,
        free_tags_count: 2,
      )
      expect(error.query_obj).to be(tq)
      expect(error.tag_count).to eq(10)
      expect(error.free_tags_count).to eq(2)
    end

    it "is raised when the tag count exceeds the configured limit" do
      # Stub the limit to 2 so we can trigger it with 3 plain tags.
      allow(Danbooru.config.custom_configuration).to receive(:tag_query_limit).and_return(2)

      expect do
        TagQuery.new("tag_a tag_b tag_c", resolve_aliases: false)
      end.to raise_error(TagQuery::CountExceededError)
    end

    it "tag_count is nil on an auto-raised error (bare raise does not populate it)" do
      allow(Danbooru.config.custom_configuration).to receive(:tag_query_limit).and_return(1)

      error = nil
      begin
        TagQuery.new("tag_a tag_b", resolve_aliases: false)
      rescue TagQuery::CountExceededError => e
        error = e
      end

      expect(error).to be_present
      expect(error.tag_count).to be_nil
    end
  end

  describe TagQuery::DepthExceededError do
    it "is a StandardError" do
      expect(TagQuery::DepthExceededError.new).to be_a(StandardError)
    end

    it "exposes a depth attribute" do
      error = TagQuery::DepthExceededError.new("too deep", depth: 11)
      expect(error.depth).to eq(11)
    end

    it "is raised when group nesting exceeds DEPTH_LIMIT (10)" do
      # An anchor tag is required alongside the group so that scan_search's
      # EARLY_SCAN_SEARCH_CHECK doesn't silently unwrap the outer level.
      # The group itself then passes through pq_count_tags → match_tokens
      # (error_on_depth_exceeded: true), which raises at depth 10.
      deeply_nested = "anchor_tag #{'( ' * 10}tag#{' )' * 10}"

      expect do
        TagQuery.new(deeply_nested, resolve_aliases: false)
      end.to raise_error(TagQuery::DepthExceededError)
    end

    it "is NOT raised for nesting right at or below the safe limit" do
      # 9 levels is within the allowed range
      safely_nested = "anchor_tag #{'( ' * 9}tag#{' )' * 9}"

      expect do
        TagQuery.new(safely_nested, resolve_aliases: false)
      end.not_to raise_error
    end
  end

  describe TagQuery::InvalidTagError do
    it "is a StandardError" do
      expect(TagQuery::InvalidTagError.new).to be_a(StandardError)
    end

    it "exposes tag, prefix, has_wildcard, and invalid_characters attributes" do
      error = TagQuery::InvalidTagError.new(
        tag:                "bad#tag",
        prefix:             "",
        has_wildcard:       false,
        invalid_characters: ["#"],
      )
      expect(error.instance_variable_get(:@tag)).to eq("bad#tag")
      expect(error.instance_variable_get(:@prefix)).to eq("")
      expect(error.instance_variable_get(:@has_wildcard)).to be(false)
      expect(error.instance_variable_get(:@invalid_characters)).to include("#")
    end

    it "appends a wildcard notice for a ~ prefix with wildcard" do
      error = TagQuery::InvalidTagError.new(tag: "tag*", prefix: "~", has_wildcard: true)
      expect(error.message).to include("*")
    end

    it "prepends the tag name to the message" do
      error = TagQuery::InvalidTagError.new("Invalid tag in query", tag: "bad#tag")
      expect(error.message).to include("bad#tag")
    end
  end
end
