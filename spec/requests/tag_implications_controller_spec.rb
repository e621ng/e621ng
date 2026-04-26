# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplicationsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)  { create(:user) }
  let(:admin)   { create(:admin_user) }
  let(:creator) { create(:user) }

  let(:implication)         { create(:tag_implication) }
  let(:active_implication)  { create(:active_tag_implication) }
  let(:deleted_implication) { create(:deleted_tag_implication) }
  let(:creator_implication) { CurrentUser.scoped(creator) { create(:tag_implication) } }

  # ---------------------------------------------------------------------------
  # GET /tag_implications — index
  # ---------------------------------------------------------------------------

  describe "GET /tag_implications" do
    it "returns 200 for anonymous" do
      get tag_implications_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get tag_implications_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with multiple implications" do
      let!(:pending_impl)  { create(:tag_implication) }
      let!(:active_impl)   { create(:active_tag_implication) }

      it "filters by antecedent_name" do
        get tag_implications_path(search: { antecedent_name: pending_impl.antecedent_name }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(pending_impl.id)
        expect(ids).not_to include(active_impl.id)
      end

      it "filters by status" do
        get tag_implications_path(search: { status: "active" }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(active_impl.id)
        expect(ids).not_to include(pending_impl.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tag_implications/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /tag_implications/:id" do
    it "returns 200 for anonymous" do
      get tag_implication_path(implication)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 JSON with implication attributes" do
      get tag_implication_path(implication, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => implication.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tag_implications/:id/edit — edit (admin_only)
  # ---------------------------------------------------------------------------

  describe "GET /tag_implications/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_tag_implication_path(implication)
      expect(response).to redirect_to(new_session_path(url: edit_tag_implication_path(implication)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_tag_implication_path(implication)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_tag_implication_path(implication)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /tag_implications/:id — update (admin_only)
  # ---------------------------------------------------------------------------

  describe "PATCH /tag_implications/:id" do
    let(:new_name) { "updated_tag_name" }
    let(:update_params) { { tag_implication: { antecedent_name: new_name } } }

    it "redirects anonymous to the login page" do
      patch tag_implication_path(implication), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch tag_implication_path(implication), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "updates a pending implication and redirects to show" do
        original_consequent = implication.consequent_name
        patch tag_implication_path(implication), params: update_params
        expect(implication.reload.antecedent_name).to eq(new_name)
        expect(implication.reload.consequent_name).to eq(original_consequent)
        expect(response).to redirect_to(tag_implication_path(implication))
      end

      it "silently skips updating a non-pending implication" do
        original_name = active_implication.antecedent_name
        patch tag_implication_path(active_implication), params: { tag_implication: { antecedent_name: new_name } }
        expect(active_implication.reload.antecedent_name).to eq(original_name)
        expect(response).to redirect_to(tag_implication_path(active_implication))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /tag_implications/:id — destroy (internal deletable_by? guard)
  # ---------------------------------------------------------------------------

  describe "DELETE /tag_implications/:id" do
    it "redirects anonymous to the login page" do
      delete tag_implication_path(implication)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member who is not the creator" do
      sign_in_as member
      delete tag_implication_path(implication)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when admin tries to delete an already-deleted implication" do
      sign_in_as admin
      delete tag_implication_path(deleted_implication)
      expect(response).to have_http_status(:forbidden)
    end

    context "as the creator of a pending implication" do
      before { sign_in_as creator }

      it "rejects the implication and redirects with a success flash" do
        creator_implication
        delete tag_implication_path(creator_implication)
        expect(creator_implication.reload.status).to eq("deleted")
        expect(response).to redirect_to(tag_implications_path)
        expect(flash[:notice]).to eq("Tag implication was deleted")
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "rejects a pending implication and redirects with a success flash" do
        delete tag_implication_path(implication)
        expect(implication.reload.status).to eq("deleted")
        expect(response).to redirect_to(tag_implications_path)
        expect(flash[:notice]).to eq("Tag implication was deleted")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tag_implications/:id/approve — approve (admin_only)
  # ---------------------------------------------------------------------------

  describe "POST /tag_implications/:id/approve" do
    it "redirects anonymous to the login page" do
      post approve_tag_implication_path(implication)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post approve_tag_implication_path(implication)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "approves a pending implication and redirects to show" do
        post approve_tag_implication_path(implication)
        expect(implication.reload.status).to eq("queued")
        expect(response).to redirect_to(tag_implication_path(implication))
      end

      it "returns 403 when the implication is not pending" do
        post approve_tag_implication_path(active_implication)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
