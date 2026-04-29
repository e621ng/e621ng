# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionsController do
  include_context "as admin"

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /session/new
  # ---------------------------------------------------------------------------

  describe "GET /session/new" do
    it "returns 200" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session
  # ---------------------------------------------------------------------------

  describe "POST /session" do
    before do
      allow(RateLimiter).to receive(:check_limit).and_return(false)
      allow(RateLimiter).to receive(:hit)
    end

    context "when rate limited" do
      before { allow(RateLimiter).to receive(:check_limit).and_return(true) }

      it "redirects to new_session_path with a notice (HTML)" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to match(/Too many login attempts/)
      end

      it "returns 429 with an error message (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body["error"]).to match(/Too many login attempts/)
      end
    end

    context "with valid credentials" do
      it "redirects to posts_path (HTML)" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to redirect_to(posts_path)
      end

      it "redirects to a safe url param" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "/artists" } }
        expect(response).to redirect_to("/artists")
      end

      it "ignores a url param starting with //" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "//evil.example.com" } }
        expect(response).to redirect_to(posts_path)
      end

      it "ignores a url param that does not start with /" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "https://evil.example.com" } }
        expect(response).to redirect_to(posts_path)
      end

      it "returns 200 with a url key (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["url"]).to eq(posts_path)
      end

      it "sets session[:user_id] to the authenticated user" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(session[:user_id]).to eq(member.id)
      end
    end

    context "with invalid credentials" do
      it "redirects to new_session_path with a notice (HTML)" do
        post session_path, params: { session: { name: member.name, password: "wrong_password" } }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to match(/incorrect/i)
      end

      it "returns 401 with an error message (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "wrong_password" } }
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /session
  # ---------------------------------------------------------------------------

  describe "DELETE /session" do
    before do
      allow(RateLimiter).to receive(:check_limit).and_return(false)
      allow(RateLimiter).to receive(:hit)
      make_session(member)
    end

    it "redirects to posts_path" do
      delete session_path
      expect(response).to redirect_to(posts_path)
    end

    it "clears session[:user_id]" do
      delete session_path
      expect(session[:user_id]).to be_nil
    end

    it "sets a logged-out flash notice" do
      delete session_path
      expect(flash[:notice]).to eq("You are now logged out")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /session/confirm_password
  # ---------------------------------------------------------------------------

  describe "GET /session/confirm_password" do
    it "returns 200" do
      sign_in_as member
      get confirm_password_session_path
      expect(response).to have_http_status(:ok)
    end
  end
end
