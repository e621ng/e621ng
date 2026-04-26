# frozen_string_literal: true

require "rails_helper"

RSpec.describe BansController do
  # Set a current user before each example so that factory callbacks that
  # require a current user do not raise NoMethodError inside `let` blocks.
  # Requests override this via the `sign_in_as` stub.
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)     { create(:user) }
  let(:moderator)  { create(:moderator_user) }
  let(:admin)      { create(:admin_user) }
  let(:ban_target) { create(:user) }
  # The factory sets an explicit banner (moderator_user) so no CurrentUser swap is needed.
  let(:ban) { create(:ban, user: ban_target) }

  # ---------------------------------------------------------------------------
  # GET /bans — index
  # ---------------------------------------------------------------------------

  describe "GET /bans" do
    it "returns 200 for anonymous" do
      get bans_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get bans_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get bans_path
      expect(response).to have_http_status(:ok)
    end

    context "with expired and active bans" do
      let!(:active_ban) { ban }
      let!(:expired_ban) do
        create(:ban, user: create(:user)).tap { |b| b.update_columns(expires_at: 1.day.ago) }
      end

      it "filters to only expired bans when search[expired]=true" do
        get bans_path(search: { expired: "true" }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(expired_ban.id)
        expect(ids).not_to include(active_ban.id)
      end

      it "filters to only unexpired bans when search[expired]=false" do
        get bans_path(search: { expired: "false" }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(active_ban.id)
        expect(ids).not_to include(expired_ban.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bans/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /bans/:id" do
    it "returns 200 for anonymous" do
      get ban_path(ban)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 JSON with ban attributes" do
      get ban_path(ban, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => ban.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bans/new — new
  # ---------------------------------------------------------------------------

  describe "GET /bans/new" do
    it "redirects anonymous to the login page" do
      get new_ban_path
      expect(response).to redirect_to(new_session_path(url: new_ban_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_ban_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get new_ban_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bans/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /bans/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_ban_path(ban)
      expect(response).to redirect_to(new_session_path(url: edit_ban_path(ban)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_ban_path(ban)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get edit_ban_path(ban)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /bans — create
  # ---------------------------------------------------------------------------

  describe "POST /bans" do
    let(:valid_params) { { ban: { user_id: ban_target.id, reason: "Violation of rules.", duration: 30 } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post bans_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post bans_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post bans_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "creates a ban and redirects with a success flash" do
        expect { post bans_path, params: valid_params }.to change(Ban, :count).by(1)
        expect(response).to redirect_to(ban_path(Ban.last))
        expect(flash[:notice]).to eq("Ban created")
      end

      it "creates a ban via user_name" do
        expect do
          post bans_path, params: { ban: { user_name: ban_target.name, reason: "Violation.", duration: 30 } }
        end.to change(Ban, :count).by(1)
        expect(Ban.last.user).to eq(ban_target)
      end

      it "re-renders the new form when the target is an admin" do
        expect do
          post bans_path, params: { ban: { user_id: admin.id, reason: "Test.", duration: 30 } }
        end.not_to change(Ban, :count)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /bans/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /bans/:id" do
    let(:update_params) { { ban: { reason: "Updated reason.", duration: 60 } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch ban_path(ban), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch ban_path(ban, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch ban_path(ban), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "updates the ban and redirects with a success flash" do
        patch ban_path(ban), params: update_params
        expect(ban.reload.reason).to eq("Updated reason.")
        expect(response).to redirect_to(ban_path(ban))
        expect(flash[:notice]).to eq("Ban updated")
      end

      it "re-renders the edit form when reason is blank" do
        patch ban_path(ban), params: { ban: { reason: "", duration: 30 } }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /bans/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /bans/:id" do
    it "redirects anonymous to the login page" do
      delete ban_path(ban)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete ban_path(ban)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "destroys the ban and redirects with a success flash" do
        ban_id = ban.id
        expect { delete ban_path(ban) }.to change(Ban, :count).by(-1)
        expect(Ban.find_by(id: ban_id)).to be_nil
        expect(response).to redirect_to(bans_path)
        expect(flash[:notice]).to eq("Ban destroyed")
      end
    end
  end
end
