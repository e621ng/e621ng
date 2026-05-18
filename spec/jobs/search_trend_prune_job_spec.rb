# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendPruneJob do
  describe "#perform" do
    it "prunes hourly and daily search trend records" do
      allow(SearchTrendHourly).to receive(:prune!)
      allow(SearchTrend).to receive(:prune!)
      described_class.perform_now
      expect(SearchTrendHourly).to have_received(:prune!)
      expect(SearchTrend).to have_received(:prune!)
    end
  end
end
