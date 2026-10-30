# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenPanelTrackJob do
  it "sends the event through OpenPanelClient" do
    allow(OpenPanelClient).to receive(:track)
    described_class.new.perform("post_created", { "rating" => "s" })
    expect(OpenPanelClient).to have_received(:track).with("post_created", { "rating" => "s" })
  end

  it "lets client errors propagate so Sidekiq retries" do
    allow(OpenPanelClient).to receive(:track).and_raise(OpenPanelClient::Error)
    expect { described_class.new.perform("post_created", {}) }.to raise_error(OpenPanelClient::Error)
  end
end
