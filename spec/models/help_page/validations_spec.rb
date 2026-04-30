# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           HelpPage Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # name — presence
  # -------------------------------------------------------------------------
  describe "name presence" do
    it "is invalid when name is blank" do
      page = build(:help_page, name: "")
      expect(page).not_to be_valid
      expect(page.errors[:name]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # wiki_page — presence
  # -------------------------------------------------------------------------
  describe "wiki_page presence" do
    it "is invalid when wiki_page is blank" do
      page = build(:help_page, wiki_page: "")
      expect(page).not_to be_valid
      expect(page.errors[:wiki_page]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # name — uniqueness
  # -------------------------------------------------------------------------
  describe "name uniqueness" do
    it "is invalid when name is already taken" do
      create(:help_page, name: "unique_name")
      duplicate = build(:help_page, name: "unique_name")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  # -------------------------------------------------------------------------
  # wiki_page — uniqueness
  # -------------------------------------------------------------------------
  describe "wiki_page uniqueness" do
    it "is invalid when wiki_page title is already used by another help page" do
      existing = create(:help_page)
      duplicate = build(:help_page, wiki: existing.wiki, wiki_page: existing.wiki_page)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:wiki_page]).to include("has already been taken")
    end
  end

  # -------------------------------------------------------------------------
  # wiki_page_exists — custom validator
  # -------------------------------------------------------------------------
  describe "wiki_page_exists" do
    it "is invalid when wiki_page references a non-existent wiki page title" do
      page = build(:help_page, wiki_page: "this_wiki_page_does_not_exist")
      # Clear the association cache so the validator hits the DB lookup.
      page.wiki = nil
      expect(page).not_to be_valid
      expect(page.errors[:wiki_page]).to include("must exist")
    end

    it "is valid when wiki_page references an existing wiki page title" do
      wiki = create(:wiki_page)
      page = build(:help_page, wiki: wiki, wiki_page: wiki.title)
      expect(page).to be_valid, page.errors.full_messages.join(", ")
    end
  end
end
