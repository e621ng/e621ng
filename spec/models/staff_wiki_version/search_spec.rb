# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        StaffWikiVersion Search                              #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWikiVersion do
  include_context "as admin"

  # Versions are created automatically via StaffWiki callbacks.
  # Each create(:staff_wiki) produces exactly one StaffWikiVersion.
  let!(:wiki_alpha) { create(:staff_wiki, title: "srch_alpha_page", body: "alpha body text") }
  let!(:wiki_beta)  { create(:staff_wiki, title: "srch_beta_page",  body: "beta body text") }

  let(:version_alpha) { wiki_alpha.versions.first }
  let(:version_beta)  { wiki_beta.versions.first }

  # -------------------------------------------------------------------------
  # .search — staff_wiki_id param
  # -------------------------------------------------------------------------
  describe ".search" do
    describe "staff_wiki_id param" do
      it "returns only the version for the given staff_wiki_id" do
        result = StaffWikiVersion.search(staff_wiki_id: wiki_alpha.id.to_s)
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "returns all versions when staff_wiki_id is absent" do
        result = StaffWikiVersion.search({})
        expect(result).to include(version_alpha, version_beta)
      end

      it "returns no results when staff_wiki_id is too large" do
        result = StaffWikiVersion.search(staff_wiki_id: "995859912741")
        expect(result).to be_empty
      end
    end

    # -------------------------------------------------------------------------
    # updater_name param (via where_user)
    # -------------------------------------------------------------------------
    describe "updater_name param" do
      it "returns versions updated by the named user" do
        other_user = create(:user)
        other_wiki = CurrentUser.scoped(other_user, "127.0.0.1") { create(:staff_wiki) }
        other_version = other_wiki.versions.first

        result = StaffWikiVersion.search(updater_name: other_user.name)
        expect(result).to include(other_version)
        expect(result).not_to include(version_alpha)
      end

      it "excludes versions from other updaters" do
        other_user = create(:user)
        other_wiki = CurrentUser.scoped(other_user, "127.0.0.1") { create(:staff_wiki) }
        other_version = other_wiki.versions.first

        result = StaffWikiVersion.search(updater_name: CurrentUser.name)
        expect(result).to include(version_alpha, version_beta)
        expect(result).not_to include(other_version)
      end
    end

    # -------------------------------------------------------------------------
    # title param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "title param" do
      it "returns the version with an exact matching title" do
        result = StaffWikiVersion.search(title: "srch_alpha_page")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "supports a trailing wildcard" do
        result = StaffWikiVersion.search(title: "srch_*")
        expect(result).to include(version_alpha, version_beta)
      end
    end

    # -------------------------------------------------------------------------
    # body param (via attribute_matches)
    # -------------------------------------------------------------------------
    describe "body param" do
      it "returns the version with a matching body" do
        result = StaffWikiVersion.search(body: "alpha body text")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end

      it "supports a trailing wildcard" do
        result = StaffWikiVersion.search(body: "alpha*")
        expect(result).to include(version_alpha)
        expect(result).not_to include(version_beta)
      end
    end

    # -------------------------------------------------------------------------
    # ip_addr param (CIDR via <<=)
    # -------------------------------------------------------------------------
    describe "ip_addr param" do
      it "returns versions whose updater_ip_addr falls within the given CIDR" do
        # The "as admin" context sets CurrentUser.ip_addr = "127.0.0.1",
        # so all versions created above have updater_ip_addr = "127.0.0.1".
        result = StaffWikiVersion.search(ip_addr: "127.0.0.1")
        expect(result).to include(version_alpha, version_beta)
      end

      it "excludes versions outside the given CIDR" do
        result = StaffWikiVersion.search(ip_addr: "192.168.0.0/24")
        expect(result).not_to include(version_alpha)
      end
    end

    # -------------------------------------------------------------------------
    # order param (via apply_basic_order)
    # -------------------------------------------------------------------------
    describe "order param" do
      it "defaults to newest first" do
        ids = StaffWikiVersion.search({}).ids
        expect(ids.index(version_beta.id)).to be < ids.index(version_alpha.id)
      end
    end
  end
end
