# frozen_string_literal: true

require "rails_helper"

#                               Prefix Verb  URI Pattern                                            Controller#Action
#                 staff_wiki_versions GET   /staff_wiki_versions(.:format)                         staff_wiki_versions#index
#                  staff_wiki_version GET   /staff_wiki_versions/:id(.:format)                     staff_wiki_versions#show
#             diff_staff_wiki_versions GET  /staff_wiki_versions/diff(.:format)                    staff_wiki_versions#diff
RSpec.describe StaffWikiVersionsController do
  include_context "as janitor"

  let(:member)  { create(:user,         created_at: 2.weeks.ago) }
  let(:janitor) { create(:janitor_user, created_at: 2.weeks.ago) }
  let(:admin)   { create(:admin_user,   created_at: 2.weeks.ago) }

  let(:staff_wiki) { create(:staff_wiki) }
  let(:version)    { staff_wiki.versions.last }

  # ---------------------------------------------------------------------------
  # Access control
  # ---------------------------------------------------------------------------

  describe "access control" do
    it "returns 403 on index for a member" do
      sign_in_as member
      get staff_wiki_versions_path
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous to login on index" do
      get staff_wiki_versions_path
      expect(response).to redirect_to(new_session_path(url: staff_wiki_versions_path))
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wiki_versions — index
  # ---------------------------------------------------------------------------

  describe "GET /staff_wiki_versions" do
    it "returns 200 for a janitor (global listing)" do
      sign_in_as janitor
      get staff_wiki_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a janitor (page-scoped listing)" do
      sign_in_as janitor
      get staff_wiki_versions_path, params: { search: { staff_wiki_id: staff_wiki.id } }
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      sign_in_as janitor
      get staff_wiki_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wiki_versions/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /staff_wiki_versions/:id" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get staff_wiki_version_path(version)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wiki_versions/diff — diff
  # ---------------------------------------------------------------------------

  describe "GET /staff_wiki_versions/diff" do
    it "returns 200 when two version IDs are provided" do
      sign_in_as janitor
      staff_wiki.update!(body: "second version")
      versions = staff_wiki.versions.order(:id).to_a
      get diff_staff_wiki_versions_path, params: { thispage: versions.first.id, otherpage: versions.second.id }
      expect(response).to have_http_status(:ok)
    end

    it "redirects back when params are missing" do
      sign_in_as janitor
      get diff_staff_wiki_versions_path
      expect(response).to be_redirect
    end
  end

  # ---------------------------------------------------------------------------
  # IP address search gating
  # ---------------------------------------------------------------------------

  describe "ip_addr search" do
    it "returns an error for a non-admin janitor passing ip_addr" do
      sign_in_as janitor
      get staff_wiki_versions_path(format: :json), params: { search: { ip_addr: "127.0.0.1" } }
      expect(response).not_to have_http_status(:ok)
    end

    it "returns 200 for an admin passing ip_addr" do
      sign_in_as admin
      get staff_wiki_versions_path(format: :json), params: { search: { ip_addr: "127.0.0.1/32" } }
      expect(response).to have_http_status(:ok)
    end
  end
end
