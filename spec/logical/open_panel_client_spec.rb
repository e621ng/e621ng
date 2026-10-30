# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenPanelClient do
  let(:conn) { instance_double(Faraday::Connection) }
  let(:req) { Struct.new(:body, :headers).new(nil, {}) }

  before do
    allow(Faraday).to receive(:new).and_return(conn)
    allow(Danbooru.config.custom_configuration).to receive_messages(
      openpanel_api_url: "https://op.example.com/api",
      openpanel_server_client_id: "test-id",
      openpanel_server_client_secret: "test-secret",
    )
  end

  def stub_response(status)
    allow(conn).to receive(:post).and_yield(req).and_return(instance_double(Faraday::Response, status: status, success?: (200..299).cover?(status)))
  end

  describe ".enabled?" do
    it "is true when both id and secret are set" do
      expect(described_class.enabled?).to be(true)
    end

    it "is false when the secret is missing" do
      allow(Danbooru.config.custom_configuration).to receive(:openpanel_server_client_secret).and_return(nil)
      expect(described_class.enabled?).to be(false)
    end

    it "is false when the id is missing" do
      allow(Danbooru.config.custom_configuration).to receive(:openpanel_server_client_id).and_return(nil)
      expect(described_class.enabled?).to be(false)
    end
  end

  describe ".track" do
    it "posts the event with client credentials" do
      stub_response(200)
      described_class.track("post_created", { "rating" => "s" })
      expect(conn).to have_received(:post).with("https://op.example.com/api/track")
      expect(req.headers).to include(
        "Content-Type" => "application/json",
        "openpanel-client-id" => "test-id",
        "openpanel-client-secret" => "test-secret",
      )
      expect(JSON.parse(req.body)).to eq("type" => "track", "payload" => { "name" => "post_created", "properties" => { "rating" => "s" } })
    end

    it "raises on an error response" do
      stub_response(401)
      expect { described_class.track("post_created") }.to raise_error(OpenPanelClient::Error, /HTTP 401/)
    end
  end
end
