# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnstileVerifier do
  let(:conn) { instance_double(Faraday::Connection) }
  let(:req) { Struct.new(:body, :headers).new(nil, {}) }

  before do
    allow(Faraday).to receive(:new).and_return(conn)
    allow(Danbooru.config.custom_configuration).to receive(:turnstile_secret_key).and_return("test-secret")
  end

  def stub_response(body)
    allow(conn).to receive(:post).and_yield(req).and_return(instance_double(Faraday::Response, body: body))
  end

  describe ".verify" do
    it "returns true when Cloudflare reports success" do
      stub_response({ success: true }.to_json)
      expect(described_class.verify("token", "1.2.3.4")).to be(true)
    end

    it "returns false when Cloudflare reports failure" do
      stub_response({ "success" => false, "error-codes" => ["invalid-input-response"] }.to_json)
      expect(described_class.verify("token", "1.2.3.4")).to be(false)
    end

    it "posts the secret, token, and remote IP" do
      stub_response({ success: true }.to_json)
      described_class.verify("token", "1.2.3.4")
      expect(conn).to have_received(:post).with(described_class::SITEVERIFY_URL)
      expect(URI.decode_www_form(req.body).to_h).to eq("secret" => "test-secret", "response" => "token", "remoteip" => "1.2.3.4")
    end

    it "returns false without a request for a blank token" do
      allow(conn).to receive(:post)
      expect(described_class.verify("", "1.2.3.4")).to be(false)
      expect(described_class.verify(nil, "1.2.3.4")).to be(false)
      expect(conn).not_to have_received(:post)
    end

    it "returns false without a request for an oversized token" do
      allow(conn).to receive(:post)
      expect(described_class.verify("a" * 2049, "1.2.3.4")).to be(false)
      expect(conn).not_to have_received(:post)
    end

    it "returns false on a network error" do
      allow(conn).to receive(:post).and_raise(Faraday::TimeoutError)
      expect(described_class.verify("token", "1.2.3.4")).to be(false)
    end

    it "returns false on an unparseable response" do
      stub_response("<html>bad gateway</html>")
      expect(described_class.verify("token", "1.2.3.4")).to be(false)
    end
  end
end
