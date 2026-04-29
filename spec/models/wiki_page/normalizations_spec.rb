# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          WikiPage Normalizations                            #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # normalize_title (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_title" do
    it "downcases the title" do
      page = create(:wiki_page, title: "MyTitle")
      expect(page.title).to eq("mytitle")
    end

    it "converts spaces to underscores" do
      page = create(:wiki_page, title: "a page title")
      expect(page.title).to eq("a_page_title")
    end

    it "strips the category-1 prefix and sets category_id to 1" do
      cat1 = TagCategory::REVERSE_MAPPING[1]
      page = build(:wiki_page, title: "#{cat1}:some_tag")
      page.valid?
      expect(page.title).to eq("some_tag")
      expect(page.category_id).to eq(1)
    end

    it "strips the species: prefix and sets category_id to species" do
      page = build(:wiki_page, title: "species:some_species")
      page.valid?
      expect(page.title).to eq("some_species")
      expect(page.category_id).to eq(5) # species
    end

    it "strips the character: prefix and sets category_id to character" do
      page = build(:wiki_page, title: "character:some_character")
      page.valid?
      expect(page.title).to eq("some_character")
      expect(page.category_id).to eq(4) # character
    end

    it "leaves titles without a category prefix unchanged" do
      page = create(:wiki_page, title: "plain_title")
      expect(page.title).to eq("plain_title")
    end

    it "handles an uppercased category prefix (e.g. 'Artist:foo')" do
      page = build(:wiki_page, title: "Artist:foo_artist")
      page.valid?
      expect(page.title).to eq("foo_artist")
      expect(page.category_id).to eq(1) # artist
    end
  end

  # -------------------------------------------------------------------------
  # normalize_other_names (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_other_names" do
    it "applies NFKC unicode normalization to each name" do
      # U+2126 OHM SIGN normalizes to U+03A9 GREEK CAPITAL LETTER OMEGA
      page = build(:wiki_page, other_names: ["\u2126"])
      page.valid?
      expect(page.other_names).to eq(["\u03A9"])
    end

    it "collapses multiple whitespace characters into a single underscore" do
      page = build(:wiki_page, other_names: ["foo  bar"])
      page.valid?
      expect(page.other_names).to eq(["foo_bar"])
    end

    it "strips leading and trailing whitespace before converting to underscore" do
      page = build(:wiki_page, other_names: [" trimmed "])
      page.valid?
      expect(page.other_names).to eq(["trimmed"])
    end

    it "deduplicates other_names" do
      page = build(:wiki_page, other_names: %w[alias_a alias_a])
      page.valid?
      expect(page.other_names).to eq(["alias_a"])
    end

    it "results in an empty array when other_names is empty" do
      page = build(:wiki_page, other_names: [])
      page.valid?
      expect(page.other_names).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # normalize_parent (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_parent" do
    it "sets parent to nil when parent is an empty string" do
      page = build(:wiki_page, parent: "")
      page.valid?
      expect(page.parent).to be_nil
    end

    it "leaves parent unchanged when it is already nil" do
      page = build(:wiki_page, parent: nil)
      page.valid?
      expect(page.parent).to be_nil
    end

    it "leaves parent unchanged when it has a non-empty value" do
      page = build(:wiki_page, parent: "some_parent")
      page.valid?
      expect(page.parent).to eq("some_parent")
    end
  end

  # -------------------------------------------------------------------------
  # body normalization (normalizes :body)
  # -------------------------------------------------------------------------
  describe "body normalization" do
    it "converts \\r\\n line endings to \\n on save" do
      page = create(:wiki_page, body: "line one\r\nline two")
      expect(page.body).to eq("line one\nline two")
    end

    it "leaves body unchanged when it contains no \\r\\n" do
      page = create(:wiki_page, body: "line one\nline two")
      expect(page.body).to eq("line one\nline two")
    end
  end
end
