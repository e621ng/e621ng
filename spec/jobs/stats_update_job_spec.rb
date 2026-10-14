# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatsUpdateJob do
  describe "#perform" do
    it "updates the cached site statistics" do
      allow(StatsUpdater).to receive(:run!)

      described_class.new.perform

      expect(StatsUpdater).to have_received(:run!)
    end
  end
end
