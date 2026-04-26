# frozen_string_literal: true

require "rails_helper"

RSpec.describe IpBansController do
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

  let(:member) { create(:user) }
  let(:admin)  { create(:admin_user) }
  let(:ip_ban) { create(:ip_ban) }

  # ---------------------------------------------------------------------------
  # GET /ip_bans — index
  # ---------------------------------------------------------------------------

  describe "GET /ip_bans" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        get ip_bans_path
        expect(response).to redirect_to(new_session_path(url: ip_bans_path))
      end

      it "returns 403 for JSON" do
        get ip_bans_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      get ip_bans_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get ip_bans_path
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON array" do
        get ip_bans_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      context "with multiple bans" do
        let!(:spam_ban)  { create(:ip_ban, reason: "spam")  }
        let!(:other_ban) { create(:ip_ban, reason: "other") }

        it "filters by reason" do
          get ip_bans_path(format: :json, search: { reason: "spam" })
          ids = response.parsed_body.pluck("id")
          expect(ids).to include(spam_ban.id)
          expect(ids).not_to include(other_ban.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /ip_bans/new — new
  # ---------------------------------------------------------------------------

  describe "GET /ip_bans/new" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        get new_ip_ban_path
        expect(response).to redirect_to(new_session_path(url: new_ip_ban_path))
      end

      it "returns 403 for JSON" do
        get new_ip_ban_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_ip_ban_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_ip_ban_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /ip_bans — create
  # ---------------------------------------------------------------------------

  describe "POST /ip_bans" do
    let(:valid_params) { { ip_ban: { ip_addr: "5.6.7.8", reason: "spam" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post ip_bans_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post ip_bans_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post ip_bans_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates a ban and redirects to the index" do
        expect { post ip_bans_path, params: valid_params }.to change(IpBan, :count).by(1)
        expect(response).to redirect_to(ip_bans_path)
      end

      it "creates a ban via JSON and returns 201" do
        post ip_bans_path(format: :json), params: valid_params
        expect(response).to have_http_status(:created)
        # FIXME: ip_addr (inet type) is not included in the default JSON serialization
        expect(response.parsed_body).to include("id" => IpBan.last.id, "reason" => "spam")
      end

      it "re-renders the form when ip_addr is blank" do
        expect do
          post ip_bans_path, params: { ip_ban: { ip_addr: "", reason: "spam" } }
        end.not_to change(IpBan, :count)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders the form when reason is blank" do
        expect do
          post ip_bans_path, params: { ip_ban: { ip_addr: "5.6.7.8", reason: "" } }
        end.not_to change(IpBan, :count)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders the form when the subnet is too large" do
        expect do
          post ip_bans_path, params: { ip_ban: { ip_addr: "5.6.0.0/16", reason: "spam" } }
        end.not_to change(IpBan, :count)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders the form for a private address" do
        expect do
          post ip_bans_path, params: { ip_ban: { ip_addr: "192.168.1.1", reason: "spam" } }
        end.not_to change(IpBan, :count)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders the form when ip_addr is a duplicate" do
        ip_ban # persist the existing ban
        expect do
          post ip_bans_path, params: { ip_ban: { ip_addr: ip_ban.ip_addr.to_s, reason: "duplicate" } }
        end.not_to change(IpBan, :count)
        expect(response).to have_http_status(:ok)
      end

      it "logs a ModAction on create" do
        post ip_bans_path, params: valid_params
        expect(ModAction.last.action).to eq("ip_ban_create")
        expect(ModAction.last[:values]).to include("ip_addr" => "5.6.7.8")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /ip_bans/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /ip_bans/:id" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        delete ip_ban_path(ip_ban)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete ip_ban_path(ip_ban, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete ip_ban_path(ip_ban)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "destroys the ban and redirects to the index" do
        ban_id = ip_ban.id
        expect { delete ip_ban_path(ip_ban) }.to change(IpBan, :count).by(-1)
        expect(IpBan.find_by(id: ban_id)).to be_nil
        expect(response).to redirect_to(ip_bans_path)
      end

      it "logs a ModAction on destroy" do
        ban_ip = ip_ban.ip_addr.to_s
        ban_reason = ip_ban.reason
        delete ip_ban_path(ip_ban)
        expect(ModAction.last.action).to eq("ip_ban_delete")
        expect(ModAction.last[:values]).to include("ip_addr" => ban_ip, "reason" => ban_reason)
      end
    end
  end
end
