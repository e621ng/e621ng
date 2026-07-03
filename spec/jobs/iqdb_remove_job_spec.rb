# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbRemoveJob do
  describe "#perform" do
    it "calls IqdbProxy.remove_post with the given post id" do
      allow(IqdbProxy).to receive(:remove_post)
      described_class.perform_now(42)
      expect(IqdbProxy).to have_received(:remove_post).with(42)
    end
  end
end
