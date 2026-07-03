# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendCacheWarmJob do
  describe "#perform" do
    it "calls warm_rising_tags_cache! on SearchTrendHourly" do
      allow(SearchTrendHourly).to receive(:warm_rising_tags_cache!)
      described_class.perform_now
      expect(SearchTrendHourly).to have_received(:warm_rising_tags_cache!)
    end
  end
end
