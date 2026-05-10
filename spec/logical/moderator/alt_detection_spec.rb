# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::AltDetection do
  describe ".score_to_badge" do
    before do
      Setting.alt_strong_threshold   = 2.0
      Setting.alt_possible_threshold = 0.7
      Setting.alt_weak_floor         = 0.2
    end

    it "returns :strong at the strong threshold" do
      expect(described_class.score_to_badge(2.0)).to eq(:strong)
    end

    it "returns :strong above the strong threshold" do
      expect(described_class.score_to_badge(2.5)).to eq(:strong)
    end

    it "returns :possible at the possible threshold" do
      expect(described_class.score_to_badge(0.7)).to eq(:possible)
    end

    it "returns :possible between possible and strong" do
      expect(described_class.score_to_badge(1.4)).to eq(:possible)
    end

    it "returns :weak just above the weak floor" do
      expect(described_class.score_to_badge(0.21)).to eq(:weak)
    end

    it "returns nil at the weak floor" do
      expect(described_class.score_to_badge(0.2)).to be_nil
    end

    it "returns nil below the weak floor" do
      expect(described_class.score_to_badge(0.1)).to be_nil
    end
  end

  describe "setting accessors" do
    it "reads each tunable from Setting" do
      Setting.alt_cgnat_threshold = 75
      expect(described_class.cgnat_threshold).to eq(75)
    end

    it "writes each tunable to Setting" do
      described_class.lookups_per_minute = 10
      expect(Setting.alt_lookups_per_minute).to eq(10)
    end

    it "coerces enabled= from a string flag" do
      described_class.enabled = "1"
      expect(described_class.enabled?).to be true
      described_class.enabled = "0"
      expect(described_class.enabled?).to be false
    end
  end
end
