# frozen_string_literal: true

require "rails_helper"

RSpec.describe SetDiff do
  describe "#initialize" do
    let(:diff) { described_class.new(%w[a b c], %w[b c d], %w[a c e]) }

    it "computes additions, removals, and unchanged" do
      expect(diff.additions).to eq(%w[a])
      expect(diff.removals).to eq(%w[d])
      expect(diff.unchanged).to eq(%w[b c])
    end

    it "marks additions missing from latest as obsolete" do
      diff = described_class.new(%w[a b], %w[b], %w[b])
      expect(diff.obsolete_added).to eq(%w[a])
    end

    it "marks removals still present in latest as obsolete" do
      diff = described_class.new(%w[b], %w[a b], %w[a b])
      expect(diff.obsolete_removed).to eq(%w[a])
    end
  end

  describe "#changes" do
    it "pairs a removed item with a similar added item" do
      diff = described_class.new(%w[http://a.com/foo2], %w[http://a.com/foo], [])
      expect(diff.changed).to eq([%w[http://a.com/foo http://a.com/foo2]])
      expect(diff.added).to be_empty
      expect(diff.removed).to be_empty
    end

    it "does not pair dissimilar items" do
      diff = described_class.new(%w[http://zzzzzz.org/qqq], %w[http://a.com/foo], [])
      expect(diff.changed).to be_empty
      expect(diff.added).to eq(%w[http://zzzzzz.org/qqq])
      expect(diff.removed).to eq(%w[http://a.com/foo])
    end

    it "picks the closest candidate when several qualify" do
      diff = described_class.new(%w[http://a.com/foo12 http://a.com/foo2], %w[http://a.com/foo], [])
      expect(diff.changed).to eq([%w[http://a.com/foo http://a.com/foo2]])
      expect(diff.added).to eq(%w[http://a.com/foo12])
    end
  end

  describe "#find_similar" do
    before do
      allow(DidYouMean::Levenshtein).to receive(:distance).and_call_original
    end

    it "skips candidates whose length differs by more than the threshold without computing a distance" do
      diff = described_class.new(["a" * 100], ["a"], [])
      expect(diff.changed).to be_empty
      expect(DidYouMean::Levenshtein).not_to have_received(:distance)
    end

    it "skips a single pair larger than MAX_PAIR_CELLS" do
      old = "a" * 300
      new = "#{'a' * 299}b"
      diff = described_class.new([new], [old], [])
      expect(diff.changed).to be_empty
      expect(diff.added).to eq([new])
      expect(diff.removed).to eq([old])
      expect(DidYouMean::Levenshtein).not_to have_received(:distance)
    end

    it "stops pairing once MAX_TOTAL_CELLS is spent" do
      len = 200
      cells_per_pair = len * len
      old = Array.new(25) { |i| "#{'a' * (len - 2)}#{format('%02d', i)}" }
      new = Array.new(25) { |i| "#{'a' * (len - 2)}#{format('%02x', i + 50)}" }

      diff = described_class.new(new, old, [])

      expect(diff.changed.size).to be < 25
      expect(diff.added.size + diff.changed.size).to eq(25)
      expect(DidYouMean::Levenshtein).to have_received(:distance).at_most(described_class::MAX_TOTAL_CELLS / cells_per_pair).times
    end

    it "tracks the budget per instance" do
      len = 200
      old = Array.new(25) { |i| "#{'a' * (len - 2)}#{format('%02d', i)}" }
      new = Array.new(25) { |i| "#{'a' * (len - 2)}#{format('%02x', i + 50)}" }
      described_class.new(new, old, [])

      diff = described_class.new(%w[http://a.com/foo2], %w[http://a.com/foo], [])
      expect(diff.changed).to eq([%w[http://a.com/foo http://a.com/foo2]])
    end
  end
end
