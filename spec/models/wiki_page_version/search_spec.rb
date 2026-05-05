# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         WikiPageVersion Search                              #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPageVersion do
  include_context "as admin"

  # Versions are created automatically via WikiPage callbacks.
  # Each create(:wiki_page) produces exactly one WikiPageVersion.
  let!(:wiki_page_alpha)   { create(:wiki_page,         title: "srch_alpha_page", body: "alpha body text") }
  let!(:wiki_page_beta)    { create(:wiki_page,         title: "srch_beta_page",  body: "beta body text") }
  let!(:wiki_page_locked)  { create(:locked_wiki_page,  title: "srch_locked_page") }
  let!(:wiki_page_deleted) { create(:deleted_wiki_page, title: "srch_deleted_page") }

  let(:version_alpha)   { wiki_page_alpha.versions.first }
  let(:version_beta)    { wiki_page_beta.versions.first }
  let(:version_locked)  { wiki_page_locked.versions.first }
  let(:version_deleted) { wiki_page_deleted.versions.first }

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    it "returns versions where updater_id matches the given user" do
      expect(WikiPageVersion.for_user(CurrentUser.user.id)).to include(version_alpha, version_beta)
    end

    it "excludes versions from other updaters" do
      other_user = create(:user)
      other_page = CurrentUser.scoped(other_user, "127.0.0.1") { create(:wiki_page) }
      other_version = other_page.versions.first

      expect(WikiPageVersion.for_user(CurrentUser.user.id)).not_to include(other_version)
      expect(WikiPageVersion.for_user(other_user.id)).to include(other_version)
    end
  end

  # -------------------------------------------------------------------------
  # .search — wiki_page_id param
  # -------------------------------------------------------------------------
  describe ".search" do
    describe "wiki_page_id param" do
      it "returns only the version for the given wiki_page_id" do
        result = WikiPageVersion.search(wiki_page_id: wiki_page_alpha.id.to_s)
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "returns all versions when wiki_page_id is absent" do
        result = WikiPageVersion.search({})
        expect(result).to include(version_alpha, version_beta)
      end

      it "returns no results when wiki_page_id is too large" do
        result = WikiPageVersion.search(wiki_page_id: "995859912741")
        expect(result).to be_empty
      end
    end

    # -------------------------------------------------------------------------
    # updater_name param (via where_user)
    # -------------------------------------------------------------------------
    describe "updater_name param" do
      it "returns versions updated by the named user" do
        other_user = create(:user)
        other_page = CurrentUser.scoped(other_user, "127.0.0.1") { create(:wiki_page) }
        other_version = other_page.versions.first

        result = WikiPageVersion.search(updater_name: other_user.name)
        expect(result).to include(other_version)
        expect(result).not_to include(version_alpha)
      end
    end

    # -------------------------------------------------------------------------
    # title param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "title param" do
      it "returns the version with an exact matching title" do
        result = WikiPageVersion.search(title: "srch_alpha_page")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "supports a trailing wildcard" do
        result = WikiPageVersion.search(title: "srch_*")
        expect(result).to include(version_alpha, version_beta, version_locked, version_deleted)
      end
    end

    # -------------------------------------------------------------------------
    # body param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "body param" do
      it "returns the version with a matching body" do
        result = WikiPageVersion.search(body: "alpha body text")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "supports a trailing wildcard" do
        result = WikiPageVersion.search(body: "alpha*")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end
    end

    # -------------------------------------------------------------------------
    # is_locked param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "is_locked param" do
      it "returns only locked versions when is_locked is 'true'" do
        result = WikiPageVersion.search(is_locked: "true")
        expect(result).to include(version_locked)
        expect(result).not_to include(version_alpha, version_beta)
      end

      it "returns only unlocked versions when is_locked is 'false'" do
        result = WikiPageVersion.search(is_locked: "false")
        expect(result).to include(version_alpha, version_beta)
        expect(result).not_to include(version_locked)
      end
    end

    # -------------------------------------------------------------------------
    # is_deleted param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "is_deleted param" do
      it "returns only deleted versions when is_deleted is 'true'" do
        result = WikiPageVersion.search(is_deleted: "true")
        expect(result).to include(version_deleted)
        expect(result).not_to include(version_alpha, version_beta)
      end

      it "returns only non-deleted versions when is_deleted is 'false'" do
        result = WikiPageVersion.search(is_deleted: "false")
        expect(result).to include(version_alpha, version_beta)
        expect(result).not_to include(version_deleted)
      end
    end

    # -------------------------------------------------------------------------
    # ip_addr param (CIDR via <<=)
    # -------------------------------------------------------------------------
    describe "ip_addr param" do
      it "returns versions whose updater_ip_addr falls within the given CIDR" do
        # The "as admin" context sets CurrentUser.ip_addr = "127.0.0.1",
        # so all versions created above have updater_ip_addr = "127.0.0.1".
        result = WikiPageVersion.search(ip_addr: "127.0.0.1")
        expect(result).to include(version_alpha, version_beta)
      end

      it "excludes versions outside the given CIDR" do
        result = WikiPageVersion.search(ip_addr: "192.168.0.0/24")
        expect(result).not_to include(version_alpha)
      end
    end

    # -------------------------------------------------------------------------
    # order param (via apply_basic_order)
    # -------------------------------------------------------------------------
    describe "order param" do
      it "defaults to newest first" do
        ids = WikiPageVersion.search({}).ids
        expect(ids.index(version_deleted.id)).to be < ids.index(version_alpha.id)
      end
    end
  end
end
