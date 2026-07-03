# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   StaffWikiVersion Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWikiVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #pretty_title
  # -------------------------------------------------------------------------
  describe "#pretty_title" do
    it "converts underscores to spaces" do
      version = build(:staff_wiki_version, title: "some_staff_wiki_page")
      expect(version.pretty_title).to eq("some staff wiki page")
    end

    it "returns the title unchanged when it contains no underscores" do
      version = build(:staff_wiki_version, title: "plainwikipage")
      expect(version.pretty_title).to eq("plainwikipage")
    end
  end

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil when the version is the first (and only) version for its staff_wiki" do
      wiki = create(:staff_wiki)
      first_version = wiki.versions.first
      expect(first_version.previous).to be_nil
    end

    it "returns the immediately preceding version of the same staff_wiki" do
      wiki = create(:staff_wiki, body: "initial body")
      first_version = wiki.versions.first

      wiki.update!(body: "updated body")
      second_version = wiki.versions.order(:id).last

      expect(second_version.previous).to eq(first_version)
    end

    it "does not return a version belonging to a different staff_wiki" do
      wiki_a = create(:staff_wiki)
      wiki_b = create(:staff_wiki)

      # Plant wiki_b's version at a lower id so it would be a false match
      # if #previous failed to filter by staff_wiki_id.
      wiki_b.versions.first.update_columns(id: wiki_a.versions.first.id - 1)

      wiki_a.update!(body: "changed body")
      second_version = wiki_a.versions.order(:id).last

      expect(second_version.previous).not_to eq(wiki_b.versions.first)
      expect(second_version.previous.staff_wiki_id).to eq(wiki_a.id)
    end

    it "memoizes the result so the same object is returned on repeated calls" do
      wiki = create(:staff_wiki, body: "v1")
      wiki.update!(body: "v2")
      second_version = wiki.versions.order(:id).last

      result1 = second_version.previous
      result2 = second_version.previous
      expect(result1).to equal(result2)
    end
  end
end
