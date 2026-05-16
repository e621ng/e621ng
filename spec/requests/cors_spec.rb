# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS handling" do
  describe "endpoints that do not inherit from ApplicationController" do
    # Regression: /status is routed to Rails::HealthController, which bypasses
    # ApplicationController. Prior to wiring up rack-cors at the middleware
    # layer, cross-origin requests to /status.json had no Access-Control-*
    # headers and were rejected by browsers.
    it "emits Access-Control-Allow-Origin on /status.json for cross-origin requests" do
      get "/status.json", headers: { "HTTP_ORIGIN" => "https://example.com" }
      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end

    it "omits CORS headers on /status.json when no Origin header is sent" do
      get "/status.json"
      expect(response).to have_http_status(:ok)
      expect(response.headers).not_to have_key("Access-Control-Allow-Origin")
    end
  end

  describe "preflight OPTIONS requests" do
    it "responds 200 with the preflight headers" do
      process :options, "/posts.json", headers: {
        "HTTP_ORIGIN" => "https://example.com",
        "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "POST",
        "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "Authorization, Content-Type",
      }
      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Allow-Methods"]).to include("POST")
      # `headers: :any` makes rack-cors reflect every requested header back, so
      # browser JSON POSTs (which trigger preflight for Content-Type) succeed.
      allowed = response.headers["Access-Control-Allow-Headers"]
      expect(allowed).to include("Authorization")
      expect(allowed).to include("Content-Type")
    end
  end
end
