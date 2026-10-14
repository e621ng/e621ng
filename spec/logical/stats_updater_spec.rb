# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatsUpdater do
  include_context "as member"

  describe ".run!" do
    context "with no posts" do
      it "completes without error" do
        expect { described_class.run! }.not_to raise_error
      end
    end

    context "with posts" do
      before { create(:post) }

      it "completes without error and writes stats to Redis" do
        described_class.run!
        raw = Cache.redis.get("e6stats")
        expect(raw).to be_present
        stats = JSON.parse(raw, symbolize_names: true)
        expect(stats[:total_posts]).to be >= 1
      end
    end

    it "sets the last run time" do
      described_class.run!
      raw = Cache.redis.get("e6stats")
      expect(raw).to be_present
      expect(JSON.parse(raw, symbolize_names: true)[:started]).to be_present
    end

    it "correctly normalizes user level names" do
      described_class.run!
      raw = Cache.redis.get("e6stats")
      expect(raw).to be_present
      stats = JSON.parse(raw, symbolize_names: true)
      UserLevel::MAPPING.each do |name, level|
        normalized_name = UserLevel.normalize(name)
        expect(stats[:"#{normalized_name}_users"]).to eq(User.where(level: level).count)
      end
    end
  end
end
