# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelatedTagCalculator do
  describe ".cached_sample_to_array" do
    # The test environment uses a null cache store; swap in a real one.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original
    end

    it "serves repeat lookups from the cache" do
      allow(described_class).to receive(:calculate_from_sample_to_array).and_return([["bar", 3]])

      2.times { expect(described_class.cached_sample_to_array("foo", "1")).to eq([["bar", 3]]) }
      expect(described_class).to have_received(:calculate_from_sample_to_array).once
    end

    it "caches each category separately" do
      allow(described_class).to receive(:calculate_from_sample_to_array).and_return([["bar", 3]])

      described_class.cached_sample_to_array("foo", "1")
      described_class.cached_sample_to_array("foo", "4")
      expect(described_class).to have_received(:calculate_from_sample_to_array).twice
    end

    it "does not cache empty results" do
      allow(described_class).to receive(:calculate_from_sample_to_array).and_return([])

      2.times { described_class.cached_sample_to_array("foo", "1") }
      expect(described_class).to have_received(:calculate_from_sample_to_array).twice
    end

    it "expires after an hour" do
      allow(described_class).to receive(:calculate_from_sample_to_array).and_return([["bar", 3]])

      described_class.cached_sample_to_array("foo", "1")
      travel 61.minutes
      described_class.cached_sample_to_array("foo", "1")
      expect(described_class).to have_received(:calculate_from_sample_to_array).twice
    end
  end
end
