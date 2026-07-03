# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                 SearchTrendBlacklist Class Methods                          #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  # =========================================================================
  # .cached_patterns
  # =========================================================================
  #
  # The test environment uses :null_store, so Cache.fetch always executes its
  # block and queries the DB — no cache management is needed in these tests.
  # =========================================================================
  describe ".cached_patterns" do
    before { Cache.delete(SearchTrendBlacklist::CACHE_KEY) }

    it "returns an empty array when there are no blacklist entries" do
      expect(SearchTrendBlacklist.cached_patterns).to eq([])
    end

    it "returns the tag from each blacklist entry" do
      create(:search_trend_blacklist, tag: "some_tag")
      expect(SearchTrendBlacklist.cached_patterns).to include("some_tag")
    end

    it "returns tags as lowercase strings" do
      create(:search_trend_blacklist, tag: "UPPER_TAG")
      expect(SearchTrendBlacklist.cached_patterns).to include("upper_tag")
      expect(SearchTrendBlacklist.cached_patterns).not_to include("UPPER_TAG")
    end
  end

  # =========================================================================
  # .blacklisted?
  # =========================================================================
  #
  # cached_patterns is stubbed so each example isolates only the glob-matching
  # logic rather than also testing DB/cache interaction.
  # =========================================================================
  describe ".blacklisted?" do
    before do
      allow(SearchTrendBlacklist).to receive(:cached_patterns)
        .and_return(["exact_tag", "prefix_*", "sho?t"])
    end

    it "returns false for a blank string" do
      expect(SearchTrendBlacklist.blacklisted?("")).to be false
    end

    it "returns false for a whitespace-only string" do
      expect(SearchTrendBlacklist.blacklisted?("   ")).to be false
    end

    it "returns false when the blacklist is empty" do
      allow(SearchTrendBlacklist).to receive(:cached_patterns).and_return([])
      expect(SearchTrendBlacklist.blacklisted?("exact_tag")).to be false
    end

    it "returns true for an exact match" do
      expect(SearchTrendBlacklist.blacklisted?("exact_tag")).to be true
    end

    it "is case-insensitive when matching input against patterns" do
      expect(SearchTrendBlacklist.blacklisted?("EXACT_TAG")).to be true
    end

    it "returns true when the tag matches a * glob pattern" do
      expect(SearchTrendBlacklist.blacklisted?("prefix_something")).to be true
    end

    it "returns true when the tag matches a ? glob pattern" do
      # "sho?t" matches "short" (? stands in for any single character)
      expect(SearchTrendBlacklist.blacklisted?("short")).to be true
    end

    it "returns false when the tag does not match any pattern" do
      expect(SearchTrendBlacklist.blacklisted?("unrelated_tag")).to be false
    end
  end

  # =========================================================================
  # .glob_to_sql_like
  # =========================================================================
  #
  # Pure string transformation — no DB interaction. Tests each substitution
  # rule in isolation and in combination.
  # =========================================================================
  describe ".glob_to_sql_like" do
    it 'converts "*" to "%"' do
      expect(SearchTrendBlacklist.glob_to_sql_like("*")).to eq("%")
    end

    it 'converts "?" to "_"' do
      expect(SearchTrendBlacklist.glob_to_sql_like("?")).to eq("_")
    end

    it "escapes literal underscores so they are not treated as SQL wildcards" do
      # "fox_tail" → "fox\_tail"
      expect(SearchTrendBlacklist.glob_to_sql_like("fox_tail")).to eq('fox\_tail')
    end

    it "escapes literal percent signs so they are not treated as SQL wildcards" do
      # "50%_off" → "50\%\_off"
      expect(SearchTrendBlacklist.glob_to_sql_like("50%_off")).to eq('50\%\_off')
    end

    it "escapes backslashes before processing other characters" do
      # A single backslash in input should become two backslashes in output
      expect(SearchTrendBlacklist.glob_to_sql_like("\\")).to eq("\\\\")
    end

    it "converts a combined glob pattern correctly" do
      # "fox_*" → "fox\_%"  (underscore escaped, star converted)
      expect(SearchTrendBlacklist.glob_to_sql_like("fox_*")).to eq('fox\_%')
    end

    it "passes a plain tag through unchanged (no special characters)" do
      expect(SearchTrendBlacklist.glob_to_sql_like("regular")).to eq("regular")
    end
  end
end
