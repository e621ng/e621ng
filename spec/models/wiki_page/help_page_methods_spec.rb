# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      WikiPage::HelpPageMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  def make_page(overrides = {})
    create(:wiki_page, **overrides)
  end

  # -------------------------------------------------------------------------
  # validate_not_used_as_help_page (before_destroy)
  # -------------------------------------------------------------------------
  describe "validate_not_used_as_help_page" do
    it "allows destroying a wiki page that has no associated help page" do
      page = make_page
      expect { page.destroy }.to change(WikiPage, :count).by(-1)
    end

    it "prevents destroying a wiki page that is referenced by a help page" do
      page = make_page
      create(:help_page, wiki: page, wiki_page: page.title)
      expect { page.destroy }.not_to change(WikiPage, :count)
    end

    it "leaves the wiki page in the database when destroy is blocked" do
      page = make_page
      create(:help_page, wiki: page, wiki_page: page.title)
      page.destroy
      expect(WikiPage.exists?(page.id)).to be(true)
    end

    it "adds an error to :wiki_page on the record when destroy is blocked" do
      page = make_page
      create(:help_page, wiki: page, wiki_page: page.title)
      page.destroy
      expect(page.errors[:wiki_page]).to include("is used by a help page")
    end
  end

  # -------------------------------------------------------------------------
  # update_help_page (after_save, if: saved_change_to_title?)
  # -------------------------------------------------------------------------
  describe "update_help_page" do
    it "updates the help page's wiki_page to the new title when the wiki page is renamed" do
      page      = make_page(title: "original_title")
      help_page = create(:help_page, wiki: page, wiki_page: page.title)

      page.update!(title: "renamed_title")

      expect(help_page.reload.wiki_page).to eq("renamed_title")
    end

    it "does not raise when the wiki page has no associated help page" do
      page = make_page(title: "no_help_page_title")
      expect { page.update!(title: "renamed_no_help") }.not_to raise_error
    end

    it "does not update any help page when a non-title field changes" do
      page      = make_page(title: "body_update_title")
      help_page = create(:help_page, wiki: page, wiki_page: page.title)

      page.update!(body: "updated body content")

      expect(help_page.reload.wiki_page).to eq("body_update_title")
    end
  end
end
