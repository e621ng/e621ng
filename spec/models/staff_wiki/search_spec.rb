# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          StaffWiki Search                                   #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWiki do
  include_context "as admin"

  let!(:wiki_alpha) { create(:staff_wiki, title: "alpha_topic", body: "alpha content here") }
  let!(:wiki_beta)  { create(:staff_wiki, title: "beta_topic",  body: "beta content here") }

  # -------------------------------------------------------------------------
  # .search — title param (ilike)
  # -------------------------------------------------------------------------
  describe "title param" do
    it "returns pages whose title matches the search term" do
      result = StaffWiki.search(title: "alpha*")
      expect(result).to include(wiki_alpha)
      expect(result).not_to include(wiki_beta)
    end

    it "returns all pages when title is absent" do
      result = StaffWiki.search({})
      expect(result).to include(wiki_alpha, wiki_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .search — body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns pages whose body matches the search term" do
      result = StaffWiki.search(body_matches: "alpha")
      expect(result).to include(wiki_alpha)
      expect(result).not_to include(wiki_beta)
    end

    it "returns all pages when body_matches is absent" do
      result = StaffWiki.search({})
      expect(result).to include(wiki_alpha, wiki_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .search — creator_name param
  # -------------------------------------------------------------------------
  describe "creator_name param" do
    it "returns only pages created by the named user" do
      other_user = create(:user)
      other_wiki = CurrentUser.scoped(other_user, "127.0.0.1") { create(:staff_wiki) }

      result = StaffWiki.search(creator_name: CurrentUser.name)
      expect(result).to include(wiki_alpha, wiki_beta)
      expect(result).not_to include(other_wiki)
    end
  end

  # -------------------------------------------------------------------------
  # .search — creator_id param
  # -------------------------------------------------------------------------
  describe "creator_id param" do
    it "returns only pages created by the given user id" do
      result = StaffWiki.search(creator_id: wiki_alpha.creator_id.to_s)
      expect(result).to include(wiki_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # .search — order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders alphabetically by title when order is 'title'" do
      result = StaffWiki.search(order: "title").to_a
      titles = result.map(&:title)
      expect(titles).to eq(titles.sort)
    end

    it "falls back to id descending by default" do
      result = StaffWiki.search({}).to_a
      ids = result.map(&:id)
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
