# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        WikiPage Other Names Scopes                          #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  let!(:page_with_alias)    { create(:wiki_page, other_names: %w[known_alias other_name]) }
  let!(:page_without_alias) { create(:wiki_page, other_names: []) }

  # -------------------------------------------------------------------------
  # .other_names_include
  # -------------------------------------------------------------------------
  describe ".other_names_include" do
    it "returns a page whose other_names contains an exact match" do
      result = WikiPage.other_names_include("known_alias")
      expect(result).to include(page_with_alias)
    end

    it "does not return a page where other_names only partially matches" do
      result = WikiPage.other_names_include("known")
      expect(result).not_to include(page_with_alias)
    end

    it "is case-insensitive" do
      result = WikiPage.other_names_include("KNOWN_ALIAS")
      expect(result).to include(page_with_alias)
    end

    it "applies NFKC normalization to the search name before matching" do
      # Store a page whose other_name contains the OHM SIGN (\u2126),
      # which NFKC-normalizes to GREEK CAPITAL OMEGA (\u03A9).
      # normalize_other_names fires on save, so the stored value is already
      # the normalized form. Searching with the un-normalized form should
      # still find it after the scope normalizes the query argument.
      page = create(:wiki_page, other_names: ["\u2126"])
      result = WikiPage.other_names_include("\u2126")
      expect(result).to include(page)
    end

    it "returns no pages when no other_name matches" do
      result = WikiPage.other_names_include("nonexistent_alias")
      expect(result).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # .other_names_match
  # -------------------------------------------------------------------------
  describe ".other_names_match" do
    it "delegates to other_names_include when name contains no wildcard" do
      result = WikiPage.other_names_match("known_alias")
      expect(result).to include(page_with_alias)
      expect(result).not_to include(page_without_alias)
    end

    it "uses ILIKE matching when name contains an asterisk" do
      result = WikiPage.other_names_match("known_*")
      expect(result).to include(page_with_alias)
    end

    it "returns pages matching the wildcard pattern" do
      result = WikiPage.other_names_match("*_alias")
      expect(result).to include(page_with_alias)
    end

    it "does not return pages that do not match the wildcard" do
      result = WikiPage.other_names_match("completely_different_*")
      expect(result).not_to include(page_with_alias)
    end
  end
end
