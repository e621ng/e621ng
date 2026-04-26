# frozen_string_literal: true

require "rails_helper"

RSpec.describe HelpController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:admin)     { create(:admin_user) }
  let(:member)    { create(:user) }
  let(:help_page) { create(:help_page) }

  # ---------------------------------------------------------------------------
  # GET /help — index
  # ---------------------------------------------------------------------------

  describe "GET /help" do
    it "returns 200 for anonymous" do
      get help_pages_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get help_pages_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get help_pages_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /help/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /help/:id" do
    it "returns 200 when found by numeric ID" do
      get help_page_path(help_page.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 when found by name" do
      get help_page_path(help_page.name)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to the index when the name is not found" do
      get help_page_path("nonexistent_help_page_name")
      expect(response).to redirect_to(help_pages_path)
    end

    it "returns 404 when the numeric ID is not found" do
      get help_page_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /help/new — new
  # ---------------------------------------------------------------------------

  describe "GET /help/new" do
    it "redirects anonymous to the login page" do
      get new_help_page_path
      expect(response).to redirect_to(new_session_path(url: new_help_page_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get new_help_page_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_help_page_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /help/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /help/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_help_page_path(help_page)
      expect(response).to redirect_to(new_session_path(url: edit_help_page_path(help_page)))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get edit_help_page_path(help_page)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_help_page_path(help_page)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /help — create
  # ---------------------------------------------------------------------------

  describe "POST /help" do
    let(:wiki)         { create(:wiki_page) }
    let(:valid_params) { { help_page: { name: "some_topic", wiki_page: wiki.title, related: "", title: "" } } }

    it "redirects anonymous to the login page" do
      post help_pages_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      post help_pages_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates a help page and sets a success flash" do
        expect { post help_pages_path, params: valid_params }.to change(HelpPage, :count).by(1)
        expect(flash[:notice]).to eq("Help page created")
      end

      it "does not create a record when name is blank" do
        expect { post help_pages_path, params: { help_page: { name: "", wiki_page: wiki.title, related: "", title: "" } } }.not_to change(HelpPage, :count)
        expect(flash[:notice]).not_to eq("Help page created")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /help/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /help/:id" do
    let(:update_params) { { help_page: { title: "Updated Title" } } }

    it "redirects anonymous to the login page" do
      patch help_page_path(help_page), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      patch help_page_path(help_page), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "updates the help page and sets a success flash" do
        patch help_page_path(help_page), params: update_params
        expect(help_page.reload.title).to eq("Updated Title")
        expect(flash[:notice]).to eq("Help entry updated")
      end

      it "does not update when name is blank" do
        original_name = help_page.name
        patch help_page_path(help_page), params: { help_page: { name: "" } }
        expect(help_page.reload.name).to eq(original_name)
        expect(flash[:notice]).not_to eq("Help entry updated")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /help/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /help/:id" do
    it "redirects anonymous to the login page" do
      delete help_page_path(help_page)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      delete help_page_path(help_page)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the record and redirects for an admin" do
      page_id = help_page.id
      sign_in_as admin
      expect { delete help_page_path(help_page) }.to change(HelpPage, :count).by(-1)
      expect(HelpPage.find_by(id: page_id)).to be_nil
    end
  end
end
