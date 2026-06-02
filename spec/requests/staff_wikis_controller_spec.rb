# frozen_string_literal: true

require "rails_helper"

#                                  Prefix Verb   URI Pattern                                        Controller#Action
#                             staff_wikis GET    /staff_wikis(.:format)                             staff_wikis#index
#                                         POST   /staff_wikis(.:format)                             staff_wikis#create
#                          new_staff_wiki GET    /staff_wikis/new(.:format)                         staff_wikis#new
#                         edit_staff_wiki GET    /staff_wikis/:id/edit(.:format)                    staff_wikis#edit
#                              staff_wiki GET    /staff_wikis/:id(.:format)                         staff_wikis#show
#                                         PATCH  /staff_wikis/:id(.:format)                         staff_wikis#update
#                                         PUT    /staff_wikis/:id(.:format)                         staff_wikis#update
#                                         DELETE /staff_wikis/:id(.:format)                         staff_wikis#destroy
#                       revert_staff_wiki PUT    /staff_wikis/:id/revert(.:format)                  staff_wikis#revert
#                      search_staff_wikis GET    /staff_wikis/search(.:format)                      staff_wikis#search
#                 show_or_new_staff_wikis GET    /staff_wikis/show_or_new(.:format)                 staff_wikis#show_or_new
RSpec.describe StaffWikisController do
  include_context "as janitor"

  let(:member)  { create(:user,         created_at: 2.weeks.ago) }
  let(:janitor) { create(:janitor_user, created_at: 2.weeks.ago) }
  let(:admin)   { create(:admin_user,   created_at: 2.weeks.ago) }

  let(:staff_wiki) { create(:staff_wiki) }

  # ---------------------------------------------------------------------------
  # Access control — members are blocked everywhere
  # ---------------------------------------------------------------------------

  describe "access control" do
    it "returns 403 on index for a member" do
      sign_in_as member
      get staff_wikis_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 on show for a member" do
      sign_in_as member
      get staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 on new for a member" do
      sign_in_as member
      get new_staff_wiki_path
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous to login on index" do
      get staff_wikis_path
      expect(response).to redirect_to(new_session_path(url: staff_wikis_path))
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis — index
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get staff_wikis_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      sign_in_as janitor
      get staff_wikis_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis/search — search
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis/search" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get search_staff_wikis_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis/show_or_new — show_or_new
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis/show_or_new" do
    it "redirects to the existing page when the title matches" do
      sign_in_as janitor
      get show_or_new_staff_wikis_path, params: { title: staff_wiki.title }
      expect(response).to redirect_to(staff_wiki_path(staff_wiki))
    end

    it "returns 200 with a create prompt when no page matches" do
      sign_in_as janitor
      get show_or_new_staff_wikis_path, params: { title: "nonexistent_xyz_abc" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis/:id" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 as JSON" do
      sign_in_as janitor
      get staff_wiki_path(staff_wiki, format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis/new — new
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis/new" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get new_staff_wiki_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_wikis/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /staff_wikis/:id/edit" do
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get edit_staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff_wikis — create
  # ---------------------------------------------------------------------------

  describe "POST /staff_wikis" do
    it "creates a new page and redirects for a janitor" do
      sign_in_as janitor
      expect {
        post staff_wikis_path, params: { staff_wiki: { title: "new_test_page", body: "hello" } }
      }.to change(StaffWiki, :count).by(1)
      expect(response).to redirect_to(staff_wiki_path(StaffWiki.last))
    end

    it "also creates an initial version" do
      sign_in_as janitor
      post staff_wikis_path, params: { staff_wiki: { title: "version_test_page", body: "body text" } }
      expect(StaffWiki.last.versions.count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /staff_wikis/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /staff_wikis/:id" do
    it "updates the page and redirects for a janitor" do
      sign_in_as janitor
      patch staff_wiki_path(staff_wiki), params: { staff_wiki: { body: "updated body" } }
      expect(staff_wiki.reload.body).to eq("updated body")
      expect(response).to redirect_to(staff_wiki_path(staff_wiki))
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /staff_wikis/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /staff_wikis/:id" do
    it "returns 403 for a janitor (non-admin)" do
      sign_in_as janitor
      delete staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the page and redirects for an admin" do
      staff_wiki  # force creation before the change block
      sign_in_as admin
      expect {
        delete staff_wiki_path(staff_wiki)
      }.to change(StaffWiki, :count).by(-1)
      expect(response).to redirect_to(staff_wikis_path)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /staff_wikis/:id/revert — revert
  # ---------------------------------------------------------------------------

  describe "PUT /staff_wikis/:id/revert" do
    it "reverts the page content for a janitor" do
      sign_in_as janitor
      original_body = staff_wiki.body
      staff_wiki.update!(body: "changed body")
      version = staff_wiki.versions.first

      put revert_staff_wiki_path(staff_wiki), params: { version_id: version.id }
      expect(staff_wiki.reload.body).to eq(original_body)
      expect(response).to redirect_to(staff_wiki_path(staff_wiki))
    end
  end
end
