# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::StaffWikiVersionsController do
  include_context "as admin"

  let(:member)  { create(:user) }
  let(:staff)   { create(:staff_user) }
  let(:admin)   { create(:admin_user) }
  let!(:wiki)   { create(:staff_wiki) }
  let(:version) { wiki.versions.first }

  # ---------------------------------------------------------------------------
  # GET /staff/wiki_versions — index
  # ---------------------------------------------------------------------------

  describe "GET /staff/wiki_versions" do
    it "redirects anonymous to the login page for HTML" do
      get staff_wiki_versions_path
      expect(response).to redirect_to(new_session_path(url: staff_wiki_versions_path))
    end

    it "returns 403 for anonymous JSON" do
      get staff_wiki_versions_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_wiki_versions_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get staff_wiki_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a staff member" do
      sign_in_as staff
      get staff_wiki_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    describe "search by updater_id" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:staff_wiki).versions.first }
      end

      it "returns only versions for the given updater_id" do
        v = version
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { updater_id: other_user.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by updater_name" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:staff_wiki).versions.first }
      end

      it "returns only versions for the given updater_name" do
        v = version
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { updater_name: other_user.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by staff_wiki_id" do
      let!(:other_wiki) { create(:staff_wiki) }

      it "filters by staff_wiki_id" do
        v       = version
        other_v = other_wiki.versions.first
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { staff_wiki_id: wiki.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end

      it "returns no results for an out-of-range staff_wiki_id" do
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { staff_wiki_id: "995859912741" })
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    describe "search by title" do
      let!(:other_wiki) { create(:staff_wiki) }

      it "returns only versions matching the title" do
        v       = version
        other_v = other_wiki.versions.first
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { title: wiki.title })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end
    end

    describe "search by body" do
      let!(:other_wiki) { create(:staff_wiki, body: "completely different content") }

      it "returns only versions matching the body" do
        v       = version
        other_v = other_wiki.versions.first
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { body: wiki.body })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end
    end

    describe "search by ip_addr (admin-only)" do
      let!(:specific_ip_version) do
        CurrentUser.scoped(member, "9.9.9.9") { create(:staff_wiki).versions.first }
      end

      it "filters by ip_addr when signed in as admin" do
        v  = version
        sv = specific_ip_version
        sign_in_as admin
        get staff_wiki_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(sv.id)
        expect(ids).not_to include(v.id)
      end

      it "returns 403 when a non-admin passes ip_addr" do
        sign_in_as staff
        get staff_wiki_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/wiki_versions/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /staff/wiki_versions/:id" do
    it "redirects anonymous to the login page for HTML" do
      get staff_wiki_version_path(version)
      expect(response).to redirect_to(new_session_path(url: staff_wiki_version_path(version)))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_wiki_version_path(version)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get staff_wiki_version_path(version)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a non-existent id" do
      sign_in_as staff
      get staff_wiki_version_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/wiki_versions/diff — diff
  # ---------------------------------------------------------------------------

  describe "GET /staff/wiki_versions/diff" do
    let(:earlier_version) { wiki.versions.first }
    let(:later_version)   { wiki.versions.last }

    before do
      CurrentUser.scoped(staff, "127.0.0.1") { wiki.update!(body: "updated body") }
    end

    it "redirects anonymous to the login page" do
      get diff_staff_wiki_versions_path(thispage: earlier_version.id, otherpage: later_version.id)
      expect(response).to redirect_to(new_session_path(url: diff_staff_wiki_versions_path(thispage: earlier_version.id, otherpage: later_version.id)))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get diff_staff_wiki_versions_path(thispage: earlier_version.id, otherpage: later_version.id)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 with valid thispage and otherpage params" do
      sign_in_as staff
      get diff_staff_wiki_versions_path(thispage: earlier_version.id, otherpage: later_version.id)
      expect(response).to have_http_status(:ok)
    end

    it "redirects with a notice when thispage is blank" do
      sign_in_as staff
      get diff_staff_wiki_versions_path(thispage: "", otherpage: later_version.id)
      expect(response).to redirect_to(staff_wikis_path)
      expect(flash[:notice]).to eq("You must select two versions to diff")
    end

    it "redirects with a notice when otherpage is blank" do
      sign_in_as staff
      get diff_staff_wiki_versions_path(thispage: earlier_version.id, otherpage: "")
      expect(response).to redirect_to(staff_wikis_path)
      expect(flash[:notice]).to eq("You must select two versions to diff")
    end
  end
end
