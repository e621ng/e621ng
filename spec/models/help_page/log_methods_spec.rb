# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          HelpPage Log Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  def make_page(overrides = {})
    create(:help_page, **overrides)
  end

  # -------------------------------------------------------------------------
  # log_create (after_create)
  # -------------------------------------------------------------------------
  describe "log_create" do
    it "creates a help_create ModAction when a help page is created" do
      expect do
        make_page
      end.to change(ModAction.where(action: "help_create"), :count).by(1)
    end

    it "records name and wiki_page in the ModAction values" do
      wiki = create(:wiki_page)
      make_page(wiki: wiki, wiki_page: wiki.title, name: "logged_help_page")

      log = ModAction.where(action: "help_create").last
      expect(log[:values]).to include(
        "name"      => "logged_help_page",
        "wiki_page" => wiki.title,
      )
    end
  end

  # -------------------------------------------------------------------------
  # log_update (after_update)
  # -------------------------------------------------------------------------
  describe "log_update" do
    it "creates a help_update ModAction when a help page is updated" do
      page = make_page
      new_wiki = create(:wiki_page)

      expect do
        page.update!(wiki: new_wiki, wiki_page: new_wiki.title)
      end.to change(ModAction.where(action: "help_update"), :count).by(1)
    end

    it "records the current name and wiki_page in the ModAction values after update" do
      page     = make_page
      new_wiki = create(:wiki_page)
      page.update!(wiki: new_wiki, wiki_page: new_wiki.title)

      log = ModAction.where(action: "help_update").last
      expect(log[:values]).to include(
        "name"      => page.name,
        "wiki_page" => new_wiki.title,
      )
    end

    it "does NOT create a help_update ModAction on create" do
      initial_count = ModAction.where(action: "help_update").count
      make_page
      expect(ModAction.where(action: "help_update").count).to eq(initial_count)
    end
  end

  # -------------------------------------------------------------------------
  # log_destroy (after_destroy)
  # -------------------------------------------------------------------------
  describe "log_destroy" do
    it "creates a help_delete ModAction when a help page is destroyed" do
      page = make_page

      expect do
        page.destroy
      end.to change(ModAction.where(action: "help_delete"), :count).by(1)
    end

    it "records name and wiki_page in the ModAction values on destroy" do
      page = make_page
      saved_name      = page.name
      saved_wiki_page = page.wiki_page
      page.destroy

      log = ModAction.where(action: "help_delete").last
      expect(log[:values]).to include(
        "name"      => saved_name,
        "wiki_page" => saved_wiki_page,
      )
    end

    it "does NOT create a help_delete ModAction on create" do
      initial_count = ModAction.where(action: "help_delete").count
      make_page
      expect(ModAction.where(action: "help_delete").count).to eq(initial_count)
    end
  end
end
