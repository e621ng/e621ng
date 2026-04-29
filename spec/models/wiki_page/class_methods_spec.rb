# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          WikiPage Class Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .normalize_name
  # -------------------------------------------------------------------------
  describe ".normalize_name" do
    it "downcases uppercase letters" do
      expect(WikiPage.normalize_name("MyTitle")).to eq("mytitle")
    end

    it "converts spaces to underscores" do
      expect(WikiPage.normalize_name("a b c")).to eq("a_b_c")
    end

    it "returns nil when passed nil" do
      expect(WikiPage.normalize_name(nil)).to be_nil
    end

    it "returns an already-normalized name unchanged" do
      expect(WikiPage.normalize_name("already_normalized")).to eq("already_normalized")
    end
  end

  # -------------------------------------------------------------------------
  # .normalize_other_name
  # -------------------------------------------------------------------------
  describe ".normalize_other_name" do
    it "applies NFKC unicode normalization" do
      # U+2126 OHM SIGN normalizes to U+03A9 GREEK CAPITAL LETTER OMEGA
      expect(WikiPage.normalize_other_name("\u2126")).to eq("\u03A9")
    end

    it "collapses multiple whitespace to a single underscore" do
      expect(WikiPage.normalize_other_name("foo  bar")).to eq("foo_bar")
    end

    it "strips leading and trailing whitespace before converting to underscore" do
      expect(WikiPage.normalize_other_name(" trimmed ")).to eq("trimmed")
    end
  end

  # -------------------------------------------------------------------------
  # .titled
  # -------------------------------------------------------------------------
  describe ".titled" do
    let!(:page) { create(:wiki_page, title: "some_titled_page") }

    it "returns the wiki page with the matching normalized title" do
      expect(WikiPage.titled("some_titled_page")).to eq(page)
    end

    it "is case-insensitive" do
      expect(WikiPage.titled("SOME_TITLED_PAGE")).to eq(page)
    end

    it "converts spaces to underscores before looking up" do
      expect(WikiPage.titled("some titled page")).to eq(page)
    end

    it "returns nil when no page matches" do
      expect(WikiPage.titled("nonexistent_page")).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    let!(:active_page)  { create(:wiki_page) }
    let!(:deleted_page) { create(:deleted_wiki_page) }

    it "returns pages where is_deleted is false" do
      expect(WikiPage.active).to include(active_page)
    end

    it "excludes pages where is_deleted is true" do
      expect(WikiPage.active).not_to include(deleted_page)
    end
  end

  # -------------------------------------------------------------------------
  # .recent
  # -------------------------------------------------------------------------
  describe ".recent" do
    it "returns at most 25 records" do
      26.times { create(:wiki_page) }
      expect(WikiPage.recent.count).to eq(25)
    end

    it "orders results by updated_at descending" do
      older = create(:wiki_page)
      newer = create(:wiki_page)
      newer.update_columns(updated_at: 1.minute.from_now)
      results = WikiPage.recent
      expect(results.first).to eq(newer)
      expect(results).to include(older)
    end
  end

  # -------------------------------------------------------------------------
  # .default_order
  # -------------------------------------------------------------------------
  describe ".default_order" do
    it "orders records by updated_at descending" do
      first  = create(:wiki_page)
      second = create(:wiki_page)
      second.update_columns(updated_at: 1.minute.from_now)
      results = WikiPage.default_order.to_a
      expect(results.index(second)).to be < results.index(first)
    end
  end
end
