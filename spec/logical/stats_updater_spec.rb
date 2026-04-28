# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatsUpdater do
  include_context "as member"

  describe ".run!" do
    before { create(:post) }

    it "completes without error and writes stats to Redis" do
      described_class.run!
      raw = Cache.redis.get("e6stats")
      expect(raw).to be_present
      stats = JSON.parse(raw, symbolize_names: true)
      expect(stats[:total_posts]).to be >= 1
    end
  end
end
