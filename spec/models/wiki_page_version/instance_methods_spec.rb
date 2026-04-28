# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    WikiPageVersion Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPageVersion do
  include_context "as admin"
  include_context "with tag categories"

  # -------------------------------------------------------------------------
  # #pretty_title
  # -------------------------------------------------------------------------
  describe "#pretty_title" do
    it "converts underscores to spaces" do
      version = build(:wiki_page_version, title: "some_wiki_page")
      expect(version.pretty_title).to eq("some wiki page")
    end

    it "returns the title unchanged when it contains no underscores" do
      version = build(:wiki_page_version, title: "plainwikipage")
      expect(version.pretty_title).to eq("plainwikipage")
    end
  end

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil when the version is the first (and only) version for its wiki_page" do
      wiki_page = create(:wiki_page)
      first_version = wiki_page.versions.first
      expect(first_version.previous).to be_nil
    end

    it "returns the immediately preceding version of the same wiki_page" do
      wiki_page = create(:wiki_page, body: "initial body")
      first_version = wiki_page.versions.first

      wiki_page.update!(body: "updated body")
      second_version = wiki_page.versions.order(:id).last

      expect(second_version.previous).to eq(first_version)
    end

    it "does not return a version belonging to a different wiki_page" do
      wiki_page_a = create(:wiki_page)
      wiki_page_b = create(:wiki_page)

      # Give wiki_page_b's version a lower id so it would be a false match
      # if #previous failed to filter by wiki_page_id.
      wiki_page_b.versions.first.update_columns(id: wiki_page_a.versions.first.id - 1)

      wiki_page_a.update!(body: "changed body")
      second_version = wiki_page_a.versions.order(:id).last

      expect(second_version.previous).not_to eq(wiki_page_b.versions.first)
      expect(second_version.previous.wiki_page_id).to eq(wiki_page_a.id)
    end

    it "memoizes the result so the same object is returned on repeated calls" do
      wiki_page = create(:wiki_page, body: "v1")
      wiki_page.update!(body: "v2")
      second_version = wiki_page.versions.order(:id).last

      result1 = second_version.previous
      result2 = second_version.previous
      expect(result1).to equal(result2)
    end
  end

  # -------------------------------------------------------------------------
  # #category_id
  # -------------------------------------------------------------------------
  describe "#category_id" do
    it "returns the correct non-zero category when a matching tag exists" do
      tag = create(:artist_tag)
      version = build(:wiki_page_version, title: tag.name)
      expect(version.category_id).to eq(artist_tag_category)
    end

    it "returns the default category (0) when no tag with that name exists" do
      version = build(:wiki_page_version, title: "nonexistent_tag_#{SecureRandom.hex(4)}")
      expect(version.category_id).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # other_names array attribute
  # -------------------------------------------------------------------------
  describe "other_names array attribute" do
    it "round-trips an array of names after persist and reload" do
      version = create(:wiki_page_version, other_names: %w[alias_one alias_two])
      expect(version.reload.other_names).to eq(%w[alias_one alias_two])
    end

    it "defaults to an empty array when not set" do
      version = create(:wiki_page_version)
      expect(version.reload.other_names).to eq([])
    end
  end
end
