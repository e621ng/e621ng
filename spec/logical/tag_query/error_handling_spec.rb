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

  # Regression: a malformed search of deeply-nested, unbalanced group parentheses
  # (e.g. "( ( ( ... ( a ) )") drove REGEX_TOKENIZE into catastrophic backtracking,
  # producing Regexp::TimeoutError 500s in production. scan_search / match_tokens now
  # reject over-deep nesting with a cheap linear pre-check before the regex runs.
  describe "deeply-nested group parenthesis guard (ReDoS)" do
    # The reported abusive query: many unbalanced opening parens.
    let(:redos_query) { "#{'( ' * 28}a ) )" }

    describe ".group_depth_exceeded?" do
      it "flags unbalanced deeply-nested parentheses" do
        expect(TagQuery.group_depth_exceeded?(redos_query)).to be(true)
      end

      it "flags balanced nesting past DEPTH_LIMIT" do
        expect(TagQuery.group_depth_exceeded?("#{'( ' * 11}tag#{' )' * 11}")).to be(true)
      end

      it "does not flag nesting within DEPTH_LIMIT" do
        expect(TagQuery.group_depth_exceeded?("#{'( ' * 10}tag#{' )' * 10}")).to be(false)
      end

      it "does not flag many balanced sibling groups" do
        many_siblings = Array.new(100) { |i| "( tag#{i} )" }.join(" ")
        expect(TagQuery.group_depth_exceeded?(many_siblings)).to be(false)
      end

      it "does not flag parentheses inside tags or quoted metatags" do
        expect(TagQuery.group_depth_exceeded?("boris_(noborhood) cat")).to be(false)
        expect(TagQuery.group_depth_exceeded?('source:"http://x/( ( ( ( ( ( ( ( ( ( ( (" cat')).to be(false)
      end

      it "does not flag tags that merely end in '(' (e.g. emoticons)" do
        # A `(` embedded in a tag is not a group opener, so 11+ such tags must not trip the guard.
        expect(TagQuery.group_depth_exceeded?("#{':( ' * 11}a )")).to be(false)
        expect(TagQuery.group_depth_exceeded?(Array.new(12) { |i| "foo#{i}(" }.join(" "))).to be(false)
      end

      it "flags prefixed group openers (-( / ~()" do
        expect(TagQuery.group_depth_exceeded?("#{'-( ' * 11}a")).to be(true)
      end

      it "flags prefixed group openers past DEPTH_LIMIT" do
        expect(TagQuery.group_depth_exceeded?("#{'-( ' * 15}a")).to be(true)
        expect(TagQuery.group_depth_exceeded?("#{'~( ' * 15}a")).to be(true)
      end
    end

    it "processes the emoticon query without error (not a false positive)" do
      # ":( :( ... a )" is not deeply-nested groups; it must scan normally, not raise.
      expect do
        TagQuery.scan_search("#{':( ' * 11}a )", error_on_depth_exceeded: true)
      end.not_to raise_error
    end

    it "raises DepthExceededError instead of hanging on the abusive query" do
      # error_on_depth_exceeded mirrors the PostSets::Post call path.
      expect do
        TagQuery.scan_search(redos_query, error_on_depth_exceeded: true)
      end.to raise_error(TagQuery::DepthExceededError)
    end

    it "returns quickly rather than backtracking, even under a strict Regexp timeout" do
      # Without the pre-check this backtracks for ~1s and raises Regexp::TimeoutError;
      # with it, the query is rejected up front and no timeout is hit.
      previous = Regexp.timeout
      Regexp.timeout = 0.5
      begin
        expect do
          TagQuery.scan_search(redos_query, error_on_depth_exceeded: true)
        end.to raise_error(TagQuery::DepthExceededError)
      ensure
        Regexp.timeout = previous
      end
    end

    it "does not blow up the regex on the full TagQuery.new parse path" do
      # TagQuery.new's default path degrades gracefully (error_on_depth_exceeded: false),
      # so it must not raise Regexp::TimeoutError under a strict timeout — the abusive query
      # is dropped up front rather than driving the tokenizer into catastrophic backtracking.
      previous = Regexp.timeout
      Regexp.timeout = 0.5
      begin
        expect do
          TagQuery.new(redos_query, resolve_aliases: false)
        end.not_to raise_error
      ensure
        Regexp.timeout = previous
      end
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
