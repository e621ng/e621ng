# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::SiteResolver do
  # Captures what the app sees for each request
  def call(headers = {})
    seen = nil
    app = ->(_env) {
      seen = { id: CurrentSite.id, safe: CurrentSite.safe_mode?, user_safe: CurrentUser.safe_mode? }
      [200, { "Content-Type" => "text/plain" }, ["OK"]]
    }
    status, _headers, body = described_class.new(app).call(Rack::MockRequest.env_for("/", headers))
    [status, body.join, seen]
  end

  it "sits inside RequestStore's middleware" do
    stack = Rails.application.middleware.middlewares
    expect(stack.index(described_class)).to be > stack.index(RequestStore::Middleware)
  end

  context "without profiles" do
    it "serves the primary site" do
      _, _, seen = call("HTTP_HOST" => "e926.net")
      expect(seen).to eq(id: "e621", safe: false, user_safe: false)
    end

    it "ignores an unknown header" do
      status, _, seen = call("HTTP_X_E6_SITE" => "bogus")
      expect(status).to eq(200)
      expect(seen[:id]).to eq("e621")
    end
  end

  context "with an e926 profile" do
    include_context "with e926 site profile"

    it "resolves the header" do
      _, _, seen = call("HTTP_X_E6_SITE" => "e926", "HTTP_HOST" => "e621.net")
      expect(seen).to eq(id: "e926", safe: true, user_safe: true)
    end

    it "falls back to the Host" do
      _, _, seen = call("HTTP_HOST" => "e926.net")
      expect(seen).to eq(id: "e926", safe: true, user_safe: true)
    end

    it "keeps safe mode when the header and Host disagree" do
      _, _, seen = call("HTTP_X_E6_SITE" => "e621", "HTTP_HOST" => "e926.net")
      expect(seen).to eq(id: "e621", safe: true, user_safe: true)
    end

    it "serves the primary site when neither matches" do
      _, _, seen = call("HTTP_HOST" => "e621.net")
      expect(seen).to eq(id: "e621", safe: false, user_safe: false)
    end

    it "normalizes case, whitespace and the port" do
      _, _, seen = call("HTTP_X_E6_SITE" => " E926 ", "HTTP_HOST" => "e621.net")
      expect(seen[:id]).to eq("e926")
      _, _, seen = call("HTTP_HOST" => "E926.net:443")
      expect(seen[:id]).to eq("e926")
    end

    it "ignores X-Forwarded-Host" do
      _, _, seen = call("HTTP_HOST" => "e926.net", "HTTP_X_FORWARDED_HOST" => "e621.net")
      expect(seen).to include(id: "e926", safe: true)
    end

    it "rejects an unknown header" do
      status, body, seen = call("HTTP_X_E6_SITE" => "bogus")
      expect(status).to eq(400)
      expect(body).to eq("Unknown site")
      expect(seen).to be_nil
    end

    it "overwrites a site left over from an earlier request" do
      CurrentSite.apply!(CurrentSite.find("e926"), true)
      _, _, seen = call("HTTP_HOST" => "e621.net")
      expect(seen).to eq(id: "e621", safe: false, user_safe: false)
    end
  end
end
