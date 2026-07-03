# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        StaffWiki Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWiki do
  # -------------------------------------------------------------------------
  # title — presence
  # -------------------------------------------------------------------------
  describe "title — presence" do
    include_context "as member"

    it "is invalid with an empty title" do
      wiki = build(:staff_wiki, title: "")
      expect(wiki).not_to be_valid
      expect(wiki.errors[:title]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # title — length
  # -------------------------------------------------------------------------
  describe "title — length" do
    include_context "as member"

    it "is invalid when title exceeds 100 characters" do
      wiki = build(:staff_wiki, title: "a" * 101)
      expect(wiki).not_to be_valid
      expect(wiki.errors[:title]).to be_present
    end

    it "is valid when title is exactly 100 characters" do
      wiki = build(:staff_wiki, title: "a" * 100)
      expect(wiki).to be_valid, wiki.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # body — length
  # -------------------------------------------------------------------------
  describe "body — length" do
    include_context "as member"

    it "is invalid when body exceeds wiki_page_max_size" do
      wiki = build(:staff_wiki, body: "a" * (Danbooru.config.wiki_page_max_size + 1))
      expect(wiki).not_to be_valid
      expect(wiki.errors[:body]).to be_present
    end

    it "is valid when body is exactly wiki_page_max_size characters" do
      wiki = build(:staff_wiki, body: "a" * Danbooru.config.wiki_page_max_size)
      expect(wiki).to be_valid, wiki.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_claimant_id
  # -------------------------------------------------------------------------
  describe "claimant_id — validate_claimant_id" do
    include_context "as member"

    it "is valid when claimant_id is nil" do
      wiki = build(:staff_wiki, claimant_id: nil)
      expect(wiki).to be_valid, wiki.errors.full_messages.join(", ")
    end

    it "is invalid when claimant_id references a nonexistent user" do
      wiki = build(:staff_wiki, claimant_id: 99_999_999)
      expect(wiki).not_to be_valid
      expect(wiki.errors[:claimant_id]).to be_present
    end

    it "is valid when claimant_id references an existing user" do
      user = create(:user)
      wiki = build(:staff_wiki, claimant_id: user.id)
      expect(wiki).to be_valid, wiki.errors.full_messages.join(", ")
    end
  end
end
