# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsUpdatesController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)      { create(:user) }
  let(:admin)       { create(:admin_user) }
  let(:news_update) { create(:news_update) }

  # ---------------------------------------------------------------------------
  # GET /news_updates — index
  # ---------------------------------------------------------------------------

  describe "GET /news_updates" do
    it "returns 200 for anonymous" do
      get news_updates_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get news_updates_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get news_updates_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get news_updates_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "orders results newest first" do
      older = create(:news_update, created_at: 2.days.ago)
      newer = create(:news_update, created_at: 1.day.ago)
      get news_updates_path(format: :json)
      ids = response.parsed_body.pluck("id")
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /news_updates/new — new
  # ---------------------------------------------------------------------------

  describe "GET /news_updates/new" do
    it "redirects anonymous to the login page" do
      get new_news_update_path
      expect(response).to redirect_to(new_session_path(url: new_news_update_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_news_update_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_news_update_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /news_updates/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /news_updates/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_news_update_path(news_update)
      expect(response).to redirect_to(new_session_path(url: edit_news_update_path(news_update)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_news_update_path(news_update)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_news_update_path(news_update)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /news_updates — create
  # ---------------------------------------------------------------------------

  describe "POST /news_updates" do
    let(:valid_params) { { news_update: { message: "New announcement." } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post news_updates_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post news_updates_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post news_updates_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates a NewsUpdate and redirects to the index" do
        expect { post news_updates_path, params: valid_params }.to change(NewsUpdate, :count).by(1)
        expect(response).to redirect_to(news_updates_path)
      end

      it "stores the submitted message" do
        post news_updates_path, params: valid_params
        expect(NewsUpdate.last.message).to eq("New announcement.")
      end

      # FIXME: NewsUpdate has no presence validation on `message`, so an empty
      # string is accepted by both the model and the NOT NULL DB constraint.
      # This test should be enabled once a validation is added to the model.
      # it "does not create a record when message is missing", pending: "NewsUpdate missing presence validation on message" do
      #   expect do
      #     post news_updates_path, params: { news_update: { message: "" } }
      #   end.not_to change(NewsUpdate, :count)
      # end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /news_updates/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /news_updates/:id" do
    let(:update_params) { { news_update: { message: "Updated announcement." } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch news_update_path(news_update), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch news_update_path(news_update, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch news_update_path(news_update), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "updates the message and redirects to the index" do
        patch news_update_path(news_update), params: update_params
        expect(news_update.reload.message).to eq("Updated announcement.")
        expect(response).to redirect_to(news_updates_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /news_updates/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /news_updates/:id" do
    it "redirects anonymous to the login page" do
      delete news_update_path(news_update)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete news_update_path(news_update)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "destroys the record" do
        record_id = news_update.id
        expect { delete news_update_path(news_update, format: :js) }.to change(NewsUpdate, :count).by(-1)
        expect(NewsUpdate.find_by(id: record_id)).to be_nil
      end
    end
  end
end
