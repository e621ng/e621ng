# frozen_string_literal: true

require "rails_helper"

RSpec.describe WikiPageVersionsController do
  include_context "as admin"

  let(:user)       { create(:user) }
  let(:admin_user) { create(:admin_user) }

  describe "GET /wiki_page_versions" do
    let!(:wiki_page) { create(:wiki_page) }
    let(:version)    { wiki_page.versions.first }

    it "returns 200 for anonymous" do
      get wiki_page_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as user
      get wiki_page_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get wiki_page_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes the auto-created version in the JSON response" do
      v = version
      get wiki_page_versions_path(format: :json)
      expect(response.parsed_body.pluck("id")).to include(v.id)
    end

    describe "search by updater_id" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:wiki_page).versions.first }
      end

      it "returns only versions for the given updater_id" do
        v = version
        get wiki_page_versions_path(format: :json, search: { updater_id: other_user.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by updater_name" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:wiki_page).versions.first }
      end

      it "returns only versions for the given updater_name" do
        v = version
        get wiki_page_versions_path(format: :json, search: { updater_name: other_user.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by wiki_page_id" do
      let!(:other_wiki_page) { create(:wiki_page) }

      it "filters by wiki_page_id" do
        v       = version
        other_v = other_wiki_page.versions.first
        get wiki_page_versions_path(format: :json, search: { wiki_page_id: wiki_page.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end

      it "returns no results for an out-of-range wiki_page_id" do
        get wiki_page_versions_path(format: :json, search: { wiki_page_id: "995859912741" })
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    describe "search by title" do
      it "returns only versions matching the title" do
        v = version
        get wiki_page_versions_path(format: :json, search: { title: wiki_page.title })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
      end

      it "excludes versions with a different title" do
        v             = version
        other_wiki    = create(:wiki_page)
        other_v       = other_wiki.versions.first
        get wiki_page_versions_path(format: :json, search: { title: wiki_page.title })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end
    end

    describe "search by is_locked" do
      let!(:locked_wiki_page) { create(:locked_wiki_page) }

      it "returns only locked versions when is_locked is true" do
        v        = version
        locked_v = locked_wiki_page.versions.first
        get wiki_page_versions_path(format: :json, search: { is_locked: "true" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(locked_v.id)
        expect(ids).not_to include(v.id)
      end

      it "returns only unlocked versions when is_locked is false" do
        v        = version
        locked_v = locked_wiki_page.versions.first
        get wiki_page_versions_path(format: :json, search: { is_locked: "false" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(locked_v.id)
      end
    end

    describe "search by is_deleted" do
      let!(:deleted_wiki_page) { create(:deleted_wiki_page) }

      it "returns only deleted versions when is_deleted is true" do
        v         = version
        deleted_v = deleted_wiki_page.versions.first
        get wiki_page_versions_path(format: :json, search: { is_deleted: "true" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(deleted_v.id)
        expect(ids).not_to include(v.id)
      end

      it "returns only non-deleted versions when is_deleted is false" do
        v         = version
        deleted_v = deleted_wiki_page.versions.first
        get wiki_page_versions_path(format: :json, search: { is_deleted: "false" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(deleted_v.id)
      end
    end

    describe "search by ip_addr (admin-only)" do
      let!(:specific_ip_version) do
        CurrentUser.scoped(user, "9.9.9.9") { create(:wiki_page).versions.first }
      end

      it "filters by ip_addr when signed in as admin" do
        v  = version
        sv = specific_ip_version
        sign_in_as admin_user
        get wiki_page_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(sv.id)
        expect(ids).not_to include(v.id)
      end

      it "returns 403 when a non-admin passes ip_addr" do
        sign_in_as user
        get wiki_page_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /wiki_page_versions/:id" do
    let!(:wiki_page) { create(:wiki_page) }
    let(:version)    { wiki_page.versions.first }

    it "returns 200 for a valid id" do
      get wiki_page_version_path(version)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a non-existent id" do
      get wiki_page_version_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /wiki_page_versions/diff" do
    let!(:wiki_page)      { create(:wiki_page) }
    let(:earlier_version) { wiki_page.versions.first }
    let(:later_version)   { wiki_page.versions.last }

    before do
      CurrentUser.scoped(user, "127.0.0.1") { wiki_page.update!(body: "updated body") }
    end

    it "returns 200 with valid thispage and otherpage params" do
      get diff_wiki_page_versions_path(thispage: earlier_version.id, otherpage: later_version.id)
      expect(response).to have_http_status(:ok)
    end

    it "redirects with a notice when thispage is blank" do
      get diff_wiki_page_versions_path(thispage: "", otherpage: later_version.id)
      expect(response).to redirect_to(wiki_pages_path)
      expect(flash[:notice]).to eq("You must select two versions to diff")
    end

    it "redirects with a notice when otherpage is blank" do
      get diff_wiki_page_versions_path(thispage: earlier_version.id, otherpage: "")
      expect(response).to redirect_to(wiki_pages_path)
      expect(flash[:notice]).to eq("You must select two versions to diff")
    end
  end
end
