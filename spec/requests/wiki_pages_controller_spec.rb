# frozen_string_literal: true

require "rails_helper"

#                           Prefix Verb   URI Pattern                                   Controller#Action
#                      wiki_pages GET    /wiki_pages(.:format)                         wiki_pages#index
#                                 POST   /wiki_pages(.:format)                         wiki_pages#create
#                   new_wiki_page GET    /wiki_pages/new(.:format)                     wiki_pages#new
#                  edit_wiki_page GET    /wiki_pages/:id/edit(.:format)                wiki_pages#edit
#                       wiki_page GET    /wiki_pages/:id(.:format)                     wiki_pages#show
#                                 PATCH  /wiki_pages/:id(.:format)                     wiki_pages#update
#                                 PUT    /wiki_pages/:id(.:format)                     wiki_pages#update
#                                 DELETE /wiki_pages/:id(.:format)                     wiki_pages#destroy
#                 revert_wiki_page PUT   /wiki_pages/:id/revert(.:format)              wiki_pages#revert
#           search_wiki_pages GET    /wiki_pages/search(.:format)                  wiki_pages#search
#        show_or_new_wiki_pages GET    /wiki_pages/show_or_new(.:format)             wiki_pages#show_or_new
RSpec.describe WikiPagesController do
  include_context "as admin"

  let(:user)       { create(:user,            created_at: 2.weeks.ago) }
  let(:privileged) { create(:privileged_user, created_at: 2.weeks.ago) }
  let(:janitor)    { create(:janitor_user,    created_at: 2.weeks.ago) }
  let(:admin)      { create(:admin_user,      created_at: 2.weeks.ago) }

  let(:wiki_page)        { create(:wiki_page) }
  let(:locked_wiki_page) { create(:locked_wiki_page) }

  # ---------------------------------------------------------------------------
  # GET /wiki_pages — index
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages" do
    it "returns 200 for anonymous" do
      get wiki_pages_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get wiki_pages_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "redirects to the single matching page when the search has exactly one result" do
      get wiki_pages_path, params: { search: { title: wiki_page.title } }
      expect(response).to redirect_to(wiki_page_path(wiki_page))
    end

    it "redirects with a wildcard when the title search has no results and no wildcard is present" do
      get wiki_pages_path, params: { search: { title: "nonexistent_title_xyz_abc" } }
      expect(response).to redirect_to(wiki_pages_path(search: { title: "*nonexistent_title_xyz_abc*" }))
    end

    it "does not redirect when on page 2 even with a matching title" do
      get wiki_pages_path, params: { search: { title: wiki_page.title }, page: 2 }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /wiki_pages/search — search
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages/search" do
    it "returns 200 for anonymous" do
      get search_wiki_pages_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /wiki_pages/show_or_new — show_or_new
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages/show_or_new" do
    it "redirects to the existing wiki page when a title matches" do
      get show_or_new_wiki_pages_path, params: { title: wiki_page.title }
      expect(response).to redirect_to(wiki_page_path(wiki_page))
    end

    it "returns 200 and renders the new-page form when no title matches" do
      get show_or_new_wiki_pages_path, params: { title: "does_not_exist_xyz_abc" }
      expect(response).to have_http_status(:ok)
    end

    it "does not crash when title param is a hash" do
      get show_or_new_wiki_pages_path, params: { title: { "$eq" => "inject" } }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /wiki_pages/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages/:id" do
    it "returns 200 by numeric ID" do
      get wiki_page_path(wiki_page.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 by title string" do
      get wiki_page_path(id: wiki_page.title)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 as JSON" do
      get wiki_page_path(wiki_page, format: :json)
      expect(response).to have_http_status(:ok)
    end

    it "renders 200 when the page has a parent set" do
      parent_page = create(:wiki_page)
      wiki_page.update_columns(parent: parent_page.title)
      get wiki_page_path(wiki_page)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to show_or_new when a title-based ID is not found (HTML)" do
      get wiki_page_path(id: "definitely_nonexistent_xyz")
      expect(response).to redirect_to(show_or_new_wiki_pages_path(title: "definitely_nonexistent_xyz"))
    end

    it "returns 404 when a title-based ID is not found (JSON)" do
      get wiki_page_path(id: "definitely_nonexistent_xyz", format: :json)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /wiki_pages/new — new
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages/new" do
    it "redirects anonymous to the login page" do
      get new_wiki_page_path
      expect(response).to redirect_to(new_session_path(url: new_wiki_page_path))
    end

    it "returns 200 for a signed-in member" do
      sign_in_as user
      get new_wiki_page_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /wiki_pages/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /wiki_pages/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_wiki_page_path(wiki_page)
      expect(response).to redirect_to(new_session_path(url: edit_wiki_page_path(wiki_page)))
    end

    it "returns 200 for a member on an unlocked page" do
      sign_in_as user
      get edit_wiki_page_path(wiki_page)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to show_or_new when the title-based ID is not found (HTML)" do
      sign_in_as user
      get edit_wiki_page_path(id: "totally_missing_page_xyz")
      expect(response).to redirect_to(show_or_new_wiki_pages_path(title: "totally_missing_page_xyz"))
    end

    it "returns 403 when a member tries to edit a locked page" do
      sign_in_as user
      get edit_wiki_page_path(locked_wiki_page)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor on a locked page" do
      sign_in_as janitor
      get edit_wiki_page_path(locked_wiki_page)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /wiki_pages — create
  # ---------------------------------------------------------------------------

  describe "POST /wiki_pages" do
    let(:valid_params) { { wiki_page: { title: "new_test_wiki_page", body: "A valid wiki body." } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post wiki_pages_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post wiki_pages_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "creates a wiki page and redirects to it" do
        expect { post wiki_pages_path, params: valid_params }.to change(WikiPage, :count).by(1)
        expect(response).to redirect_to(wiki_page_path(WikiPage.last))
      end

      it "returns 201 on JSON success" do
        post wiki_pages_path(format: :json), params: valid_params
        expect(response).to have_http_status(:created)
      end

      it "does not create a page with a blank title" do
        expect do
          post wiki_pages_path, params: { wiki_page: { title: "", body: "some body" } }
        end.not_to change(WikiPage, :count)
      end

      # FIXME: Cannot test that members cannot set is_locked or parent by passing
      # those params in the request body, because config/application.rb sets
      # `action_on_unpermitted_parameters = :raise`. Rails raises
      # ActionController::UnpermittedParameters before the model is touched,
      # so the page is never created and the assertion can't be made.
      # The filtering is covered indirectly by the positive tests for janitor
      # (can set is_locked) and privileged (can set parent).
    end

    context "as a privileged user" do
      before { sign_in_as privileged }

      it "allows setting parent to an existing wiki page title" do
        parent_page = create(:wiki_page)
        post wiki_pages_path, params: { wiki_page: { title: "child_page_privileged", body: "body", parent: parent_page.title } }
        expect(WikiPage.titled("child_page_privileged").parent).to eq(parent_page.title)
      end
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "allows setting is_locked to true" do
        post wiki_pages_path, params: { wiki_page: { title: "locktest_janitor_page", body: "body", is_locked: true } }
        expect(WikiPage.titled("locktest_janitor_page").is_locked).to be true
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "accepts the category_is_locked param without error" do
        expect do
          post wiki_pages_path, params: { wiki_page: { title: "catlock_wiki_page", body: "body", category_is_locked: true } }
        end.to change(WikiPage, :count).by(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /wiki_pages/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /wiki_pages/:id" do
    let(:update_params) { { wiki_page: { body: "Updated wiki page body." } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch wiki_page_path(wiki_page), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch wiki_page_path(wiki_page, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "updates the body of an unlocked page and redirects" do
        patch wiki_page_path(wiki_page), params: update_params
        expect(wiki_page.reload.body).to eq("Updated wiki page body.")
        expect(response).to redirect_to(wiki_page_path(wiki_page))
      end

      it "returns a successful JSON response on success" do
        patch wiki_page_path(wiki_page, format: :json), params: update_params
        expect(response).to be_successful
      end

      it "returns 403 when trying to update a locked page" do
        patch wiki_page_path(locked_wiki_page), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "can update a locked page" do
        patch wiki_page_path(locked_wiki_page), params: update_params
        expect(locked_wiki_page.reload.body).to eq("Updated wiki page body.")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /wiki_pages/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /wiki_pages/:id" do
    it "redirects anonymous to the login page" do
      delete wiki_page_path(wiki_page)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      delete wiki_page_path(wiki_page)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      delete wiki_page_path(wiki_page)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "destroys the page and sets a success flash" do
        page_id = wiki_page.id
        expect { delete wiki_page_path(wiki_page) }.to change(WikiPage, :count).by(-1)
        expect(WikiPage.find_by(id: page_id)).to be_nil
        expect(flash[:notice]).to eq("Page destroyed")
      end

      it "redirects to the wiki pages index after destroy" do
        delete wiki_page_path(wiki_page)
        expect(response).to redirect_to(wiki_pages_path)
      end

      # FIXME: The before_destroy :validate_not_used_as_help_page callback prevents
      # deletion of wiki pages used as help pages. When destroy is prevented,
      # @wiki_page.errors is populated but respond_with may still redirect rather
      # than rendering the errors clearly. Verify controller behavior and add a test
      # once the response format for a failed destroy is confirmed.
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /wiki_pages/:id/revert — revert
  # ---------------------------------------------------------------------------

  describe "PUT /wiki_pages/:id/revert" do
    it "redirects anonymous to the login page" do
      version = wiki_page.versions.order(:id).first
      put revert_wiki_page_path(wiki_page), params: { version_id: version.id }
      expect(response).to redirect_to(new_session_path)
    end

    context "as a member on an unlocked page" do
      before { sign_in_as user }

      it "reverts to the specified version and redirects with a flash notice" do
        original_body = wiki_page.body
        version = wiki_page.versions.order(:id).first
        wiki_page.update!(body: "Changed body after original.")
        put revert_wiki_page_path(wiki_page), params: { version_id: version.id }
        expect(wiki_page.reload.body).to eq(original_body)
        expect(response).to redirect_to(wiki_page_path(wiki_page))
        expect(flash[:notice]).to eq("Page was reverted")
      end

      it "returns 404 when the version_id does not belong to this page" do
        other_page = create(:wiki_page)
        other_version = other_page.versions.order(:id).first
        put revert_wiki_page_path(wiki_page), params: { version_id: other_version.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as a member on a locked page" do
      before { sign_in_as user }

      it "returns 403" do
        version = locked_wiki_page.versions.order(:id).first
        put revert_wiki_page_path(locked_wiki_page), params: { version_id: version.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor on a locked page" do
      before { sign_in_as janitor }

      it "successfully reverts the locked page and redirects" do
        original_body = locked_wiki_page.body
        version = locked_wiki_page.versions.order(:id).first
        locked_wiki_page.update_columns(body: "Directly changed without callback.")
        put revert_wiki_page_path(locked_wiki_page), params: { version_id: version.id }
        expect(locked_wiki_page.reload.body).to eq(original_body)
        expect(response).to redirect_to(wiki_page_path(locked_wiki_page))
      end
    end
  end
end
