# frozen_string_literal: true

require "rails_helper"

RSpec.describe OnboardingsController do
  before { host! "localhost:3000" }

  # ---------------------------------------------------------------------------
  # GET /onboarding — show
  # ---------------------------------------------------------------------------

  describe "GET /onboarding" do
    context "as anonymous" do
      it "redirects to login" do
        get onboarding_path
        expect(response).to redirect_to(new_session_path(url: onboarding_path))
      end
    end

    context "as a logged-in user" do
      it "returns 200" do
        sign_in_as create(:user)
        get onboarding_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /onboarding.json — show with JSON format
  # ---------------------------------------------------------------------------

  describe "GET /onboarding.json" do
    context "as anonymous" do
      it "returns 403 (forbidden)" do
        get onboarding_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a logged-in user" do
      let(:user) { create(:user) }

      before { sign_in_as user }
      
      it "returns 200" do
        get onboarding_path(format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON with user_id" do
        get onboarding_path(format: :json)
        expect(response.parsed_body).to include("user_id" => user.id)
      end

      it "returns JSON with steps" do
        get onboarding_path(format: :json)
        expect(response.parsed_body).to include("steps")
        expect(response.parsed_body["steps"]).to be_an(Array)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /onboarding/complete.json
  # ---------------------------------------------------------------------------

  describe "POST /onboarding/complete.json" do
    context "as anonymous" do
      it "returns 403 (forbidden)" do
        post complete_onboarding_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a logged-in user" do
      let(:user) { create(:user) }
      
      before do
        sign_in_as user
        allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(false)
      end

      it "returns 200" do
        post complete_onboarding_path(format: :json), params: {}
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON response" do
        post complete_onboarding_path(format: :json), params: {}
        expect(response.content_type).to include("application/json")
      end

      it "returns success in JSON response" do
        post complete_onboarding_path(format: :json), params: {}
        expect(response.parsed_body).to include("success" => true)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /onboarding/restart — restart
  # ---------------------------------------------------------------------------

  describe "POST /onboarding/restart" do
    context "as anonymous" do
      it "returns 403 (forbidden)" do
        post restart_onboarding_path(format: :html)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a logged-in user" do
      let(:user) { create(:user) }

      before do
        sign_in_as user
        allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(false)
      end
      
      it "returns 302 (redirect)" do
        post restart_onboarding_path
        expect(response).to have_http_status(:found)
      end

      it "redirects to onboarding path" do
        post restart_onboarding_path
        expect(response).to redirect_to(onboarding_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Response format tests
  # ---------------------------------------------------------------------------

  describe "response formats" do
    let(:user) { create(:user) }

    before { sign_in_as user }

    describe "HTML responses" do
      it "includes the onboarding root element" do
        get onboarding_path
        expect(response.body).to include('id="onboarding-root"')
      end

      it "includes user data in the root element" do
        get onboarding_path
        expect(response.body).to include("data-user-id=\"#{user.id}\"")
      end

      it "loads the Vite TypeScript component" do
        get onboarding_path
        expect(response.body).to include("v_onboarding")
      end
    end

    describe "JSON responses" do
      it "does not include HTML elements" do
        get onboarding_path(format: :json)
        expect(response.body).not_to include("<!DOCTYPE")
        expect(response.body).not_to include("<html")
      end

      it "is valid JSON" do
        get onboarding_path(format: :json)
        expect { JSON.parse(response.body) }.not_to raise_error
      end
    end
  end
end
