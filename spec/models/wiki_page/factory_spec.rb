# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            WikiPage Factory                                 #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # Factory sanity checks
  # -------------------------------------------------------------------------
  describe "factory" do
    it "produces a valid base wiki page with build" do
      page = build(:wiki_page)
      expect(page).to be_valid, page.errors.full_messages.join(", ")
    end

    it "produces a valid base wiki page with create" do
      page = create(:wiki_page)
      expect(page).to be_persisted
    end

    it "produces a valid locked wiki page" do
      page = create(:locked_wiki_page)
      expect(page).to be_persisted
      expect(page.is_locked).to be true
    end

    it "produces a valid deleted wiki page" do
      page = create(:deleted_wiki_page)
      expect(page).to be_persisted
      expect(page.is_deleted).to be true
    end

    it "produces a valid wiki page with other names" do
      page = create(:wiki_page_with_other_names)
      expect(page).to be_persisted
      expect(page.other_names).to include("alias_one", "alias_two")
    end

    it "produces a valid wiki page with body links" do
      page = create(:wiki_page_with_body_links)
      expect(page).to be_persisted
      expect(page.body).to include("[[some_tag]]")
    end
  end
end
