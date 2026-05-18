# frozen_string_literal: true

require "rails_helper"

RSpec.describe TermsOfUsesController do
  include_context "as admin"

  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # GET /terms_of_use — show
  # ---------------------------------------------------------------------------

  describe "GET /terms_of_use" do
    it "returns 200 for anonymous" do
      get terms_of_use_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get terms_of_use_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get terms_of_use_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /terms_of_use/accept — accept
  # ---------------------------------------------------------------------------

  describe "POST /terms_of_use/accept" do
    let(:valid_params) { { state: "accepted", age: "on", terms: "on" } }

    context "with all required params" do
      it "sets the tos_accepted cookie and redirects" do
        post accept_terms_of_use_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(cookies[:tos_accepted]).to be_present
      end
    end

    context "with missing state param" do
      it "does not set the cookie and shows a rejection notice" do
        post accept_terms_of_use_path, params: { age: "on", terms: "on" }
        expect(response).to be_redirect
        expect(cookies[:tos_accepted]).to be_nil
        expect(flash[:alert]).to include("You must accept the TOU")
      end
    end

    context "with missing age param" do
      it "does not set the cookie and shows a rejection notice" do
        post accept_terms_of_use_path, params: { state: "accepted", terms: "on" }
        expect(response).to be_redirect
        expect(cookies[:tos_accepted]).to be_nil
        expect(flash[:alert]).to include("You must accept the TOU")
      end
    end

    context "with missing terms param" do
      it "does not set the cookie and shows a rejection notice" do
        post accept_terms_of_use_path, params: { state: "accepted", age: "on" }
        expect(response).to be_redirect
        expect(cookies[:tos_accepted]).to be_nil
        expect(flash[:alert]).to include("You must accept the TOU")
      end
    end

    context "as a signed-in member" do
      before { sign_in_as member }

      it "sets the tos_accepted cookie and redirects" do
        post accept_terms_of_use_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(cookies[:tos_accepted]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /terms_of_use/clear_cache — clear_cache (admin only)
  # ---------------------------------------------------------------------------

  describe "POST /terms_of_use/clear_cache" do
    context "as admin" do
      before { sign_in_as admin }

      it "deletes the tos_content cache, shows a flash, and redirects" do
        allow(Cache).to receive(:delete)
        post clear_cache_terms_of_use_path
        expect(Cache).to have_received(:delete).with("tos_content")
        expect(flash[:notice]).to include("cleared")
        expect(response).to redirect_to(terms_of_use_path)
      end
    end

    context "as moderator" do
      it "returns 403" do
        sign_in_as moderator
        post clear_cache_terms_of_use_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as member" do
      it "returns 403" do
        sign_in_as member
        post clear_cache_terms_of_use_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as anonymous" do
      it "redirects to the login page" do
        post clear_cache_terms_of_use_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /terms_of_use/bump_version — bump_version (admin only)
  # ---------------------------------------------------------------------------

  describe "POST /terms_of_use/bump_version" do
    context "as admin" do
      before { sign_in_as admin }

      it "increments tos_version, deletes cache, shows a flash, and redirects" do
        allow(Cache).to receive(:delete)
        expect { post bump_version_terms_of_use_path }.to change(Setting, :tos_version).by(1)
        expect(Cache).to have_received(:delete).with("tos_content")
        expect(flash[:notice]).to include("bumped")
        expect(response).to redirect_to(terms_of_use_path)
      end
    end

    context "as moderator" do
      it "returns 403" do
        sign_in_as moderator
        post bump_version_terms_of_use_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as member" do
      it "returns 403" do
        sign_in_as member
        post bump_version_terms_of_use_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as anonymous" do
      it "redirects to the login page" do
        post bump_version_terms_of_use_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
