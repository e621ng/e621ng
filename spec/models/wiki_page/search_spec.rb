# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           WikiPage Search & Scopes                          #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  def make_page(overrides = {})
    create(:wiki_page, **overrides)
  end

  # Shared fixtures used across search groups.
  let!(:page_alpha)   { make_page(title: "search_alpha",   body: "contains the keyword dolphin") }
  let!(:page_beta)    { make_page(title: "search_beta",    body: "nothing special") }
  let!(:page_deleted) { make_page(title: "search_deleted", is_deleted: true) }
  let!(:page_locked)  { make_page(title: "search_locked",  is_locked: true) }

  # -------------------------------------------------------------------------
  # title param
  # -------------------------------------------------------------------------
  describe "title param" do
    it "returns pages matching the title LIKE pattern" do
      result = WikiPage.search(title: "search_alpha")
      expect(result).to include(page_alpha)
      expect(result).not_to include(page_beta)
    end

    it "supports a trailing wildcard" do
      result = WikiPage.search(title: "search_*")
      expect(result).to include(page_alpha, page_beta)
    end

    it "is case-insensitive (converts to downcase before matching)" do
      result = WikiPage.search(title: "SEARCH_ALPHA")
      expect(result).to include(page_alpha)
    end

    it "converts spaces to underscores before matching" do
      result = WikiPage.search(title: "search alpha")
      expect(result).to include(page_alpha)
    end

    it "returns all pages when title param is absent" do
      result = WikiPage.search({})
      expect(result).to include(page_alpha, page_beta)
    end
  end

  # -------------------------------------------------------------------------
  # body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns pages whose body matches the search term" do
      result = WikiPage.search(body_matches: "dolphin")
      expect(result).to include(page_alpha)
      expect(result).not_to include(page_beta)
    end

    it "returns all pages when body_matches is absent" do
      result = WikiPage.search({})
      expect(result).to include(page_alpha, page_beta)
    end
  end

  # -------------------------------------------------------------------------
  # other_names_match param
  # -------------------------------------------------------------------------
  describe "other_names_match param" do
    let!(:page_with_alias) { make_page(title: "aliased_page", other_names: ["known_alias"]) }

    it "returns pages whose other_names include an exact match" do
      result = WikiPage.search(other_names_match: "known_alias")
      expect(result).to include(page_with_alias)
      expect(result).not_to include(page_alpha)
    end

    it "returns pages matching a wildcard pattern" do
      result = WikiPage.search(other_names_match: "known_*")
      expect(result).to include(page_with_alias)
    end

    it "returns all pages when other_names_match is absent" do
      result = WikiPage.search({})
      expect(result).to include(page_alpha, page_beta)
    end
  end

  # -------------------------------------------------------------------------
  # creator filter
  # -------------------------------------------------------------------------
  describe "creator filter" do
    let(:other_creator) { create(:user) }
    let!(:page_by_other) do
      CurrentUser.user = other_creator
      p = make_page(title: "page_by_other")
      CurrentUser.user = create(:admin_user)
      p
    end

    it "filters by creator_name" do
      # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
      result = WikiPage.search(creator_name: other_creator.name)
      expect(result).to include(page_by_other)
      expect(result).not_to include(page_alpha)
    end

    it "filters by creator_id" do
      # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
      result = WikiPage.search(creator_id: other_creator.id)
      expect(result).to include(page_by_other)
      expect(result).not_to include(page_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # hide_deleted param
  # -------------------------------------------------------------------------
  describe "hide_deleted param" do
    it "excludes deleted pages when hide_deleted is truthy" do
      result = WikiPage.search(title: "search_*", hide_deleted: "1")
      expect(result).not_to include(page_deleted)
      expect(result).to include(page_alpha)
    end

    it "includes deleted pages when hide_deleted is absent" do
      result = WikiPage.search(title: "search_*")
      expect(result).to include(page_deleted)
    end
  end

  # -------------------------------------------------------------------------
  # parent param
  # -------------------------------------------------------------------------
  describe "parent param" do
    let!(:page_with_parent) { make_page(title: "child_page", parent: "search_alpha") }

    it "returns only pages whose parent matches" do
      result = WikiPage.search(parent: "search_alpha")
      expect(result).to include(page_with_parent)
      expect(result).not_to include(page_alpha)
    end

    it "converts spaces to underscores in the parent param" do
      result = WikiPage.search(parent: "search alpha")
      expect(result).to include(page_with_parent)
    end

    it "returns all pages when parent param is absent" do
      result = WikiPage.search({})
      expect(result).to include(page_alpha, page_beta)
    end
  end

  # -------------------------------------------------------------------------
  # other_names_present param
  # -------------------------------------------------------------------------
  describe "other_names_present param" do
    let!(:page_no_aliases)   { make_page(title: "no_aliases_page", other_names: []) }
    let!(:page_has_aliases)  { make_page(title: "has_aliases_page", other_names: ["an_alias"]) }

    it "returns only pages with non-empty other_names when truthy" do
      result = WikiPage.search(other_names_present: "1")
      expect(result).to include(page_has_aliases)
      expect(result).not_to include(page_no_aliases)
    end

    it "returns only pages with empty other_names when falsy" do
      result = WikiPage.search(other_names_present: "0")
      expect(result).to include(page_no_aliases)
      expect(result).not_to include(page_has_aliases)
    end
  end

  # -------------------------------------------------------------------------
  # is_locked param
  # -------------------------------------------------------------------------
  describe "is_locked param" do
    it "returns only locked pages when is_locked is 'true'" do
      result = WikiPage.search(title: "search_*", is_locked: "true")
      expect(result).to include(page_locked)
      expect(result).not_to include(page_alpha)
    end

    it "returns only unlocked pages when is_locked is 'false'" do
      result = WikiPage.search(title: "search_*", is_locked: "false")
      expect(result).not_to include(page_locked)
      expect(result).to include(page_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # is_deleted param
  # -------------------------------------------------------------------------
  describe "is_deleted param" do
    it "returns only deleted pages when is_deleted is 'true'" do
      result = WikiPage.search(title: "search_*", is_deleted: "true")
      expect(result).to include(page_deleted)
      expect(result).not_to include(page_alpha)
    end

    it "returns only active pages when is_deleted is 'false'" do
      result = WikiPage.search(title: "search_*", is_deleted: "false")
      expect(result).not_to include(page_deleted)
      expect(result).to include(page_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    let!(:page_zzz) { make_page(title: "zzz_order_page") }
    let!(:page_aaa) { make_page(title: "aaa_order_page") }

    it "orders by title ascending when order is 'title'" do
      result = WikiPage.search(title: "*_order_page", order: "title").map(&:title)
      expect(result).to eq(result.sort)
    end

    it "orders by tag post_count descending when order is 'post_count'" do
      create(:tag, name: "aaa_order_page", post_count: 10)
      create(:tag, name: "zzz_order_page", post_count: 1)
      result = WikiPage.search(title: "*_order_page", order: "post_count").to_a
      expect(result.first).to eq(page_aaa)
      expect(result.last).to eq(page_zzz)
    end

    it "orders by updated_at descending by default" do
      page_aaa.update_columns(updated_at: 1.minute.from_now)
      result = WikiPage.search(title: "*_order_page").to_a
      expect(result.first).to eq(page_aaa)
    end
  end
end
