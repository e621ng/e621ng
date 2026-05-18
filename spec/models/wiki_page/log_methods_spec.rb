# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         WikiPage Log Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  def make_page(overrides = {})
    create(:wiki_page, **overrides)
  end

  # -------------------------------------------------------------------------
  # log_changes — rename (before_save, only on update)
  # -------------------------------------------------------------------------
  describe "log_changes — title rename" do
    it "creates a wiki_page_rename ModAction when title changes on update" do
      page = make_page(title: "before_rename")
      expect do
        page.update!(title: "after_rename")
      end.to change(ModAction.where(action: "wiki_page_rename"), :count).by(1)
    end

    it "records new_title and old_title in ModAction values" do
      page = make_page(title: "original_title")
      page.update!(title: "updated_title")
      log = ModAction.where(action: "wiki_page_rename").last
      expect(log[:values]).to include(
        "new_title" => "updated_title",
        "old_title" => "original_title",
      )
    end

    it "does NOT create a wiki_page_rename action on create" do
      initial_count = ModAction.where(action: "wiki_page_rename").count
      make_page(title: "created_no_rename_log")
      expect(ModAction.where(action: "wiki_page_rename").count).to eq(initial_count)
    end
  end

  # -------------------------------------------------------------------------
  # log_changes — locking (before_save)
  # -------------------------------------------------------------------------
  describe "log_changes — locking" do
    it "creates a wiki_page_lock ModAction when is_locked changes from false to true" do
      page = make_page
      expect do
        page.update!(is_locked: true)
      end.to change(ModAction.where(action: "wiki_page_lock"), :count).by(1)
    end

    it "creates a wiki_page_unlock ModAction when is_locked changes from true to false" do
      page = make_page(is_locked: true)
      # Snapshot after creation (which may itself log a lock) to isolate the update.
      count_before = ModAction.where(action: "wiki_page_unlock").count
      page.update!(is_locked: false)
      expect(ModAction.where(action: "wiki_page_unlock").count).to eq(count_before + 1)
    end

    it "records the wiki page title in the ModAction values for wiki_page_lock" do
      page = make_page(title: "lockable_wiki")
      page.update!(is_locked: true)
      log = ModAction.where(action: "wiki_page_lock").last
      expect(log[:values]).to include("wiki_page" => "lockable_wiki")
    end

    it "does not log a lock/unlock action when is_locked is unchanged on update" do
      page = make_page
      expect do
        page.update!(body: "body change only, no lock change")
      end.not_to change(ModAction.where(action: %w[wiki_page_lock wiki_page_unlock]), :count)
    end
  end

  # -------------------------------------------------------------------------
  # log_destroy (before_destroy)
  # -------------------------------------------------------------------------
  describe "log_destroy" do
    it "creates a wiki_page_delete ModAction when a page is destroyed" do
      page = make_page
      expect do
        page.destroy!
      end.to change(ModAction.where(action: "wiki_page_delete"), :count).by(1)
    end

    it "records the wiki page title and id in the ModAction values" do
      page = make_page(title: "destroyable_wiki")
      page_id = page.id
      page.destroy!
      log = ModAction.where(action: "wiki_page_delete").last
      expect(log[:values]).to include(
        "wiki_page"    => "destroyable_wiki",
        "wiki_page_id" => page_id,
      )
    end
  end
end
