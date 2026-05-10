# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpTouchCursor do
  describe ".cursor_for" do
    it "creates a row with cutoff_at = 5.years.ago on first touch" do
      cursor = nil
      Timecop.freeze do
        cursor = described_class.cursor_for("comment")
        expect(cursor.cutoff_at).to be_within(1.second).of(5.years.ago)
      end
      expect(cursor.last_processed_id).to be_nil
      expect(cursor.last_processed_at).to be_nil
    end

    it "returns the existing row on subsequent calls without resetting cutoff_at" do
      first = described_class.cursor_for("comment")
      first.update!(last_processed_id: 42)
      sleep 0.01
      second = described_class.cursor_for("comment")
      expect(second.source).to eq(first.source)
      expect(second.cutoff_at).to be_within(1.second).of(first.cutoff_at)
      expect(second.last_processed_id).to eq(42)
    end
  end

  describe "#advance!" do
    let(:cursor) { described_class.cursor_for("comment") }

    it "updates last_processed_id" do
      cursor.advance!(last_processed_id: 100)
      expect(cursor.reload.last_processed_id).to eq(100)
    end

    it "updates last_processed_at" do
      ts = 1.hour.ago
      cursor.advance!(last_processed_at: ts)
      expect(cursor.reload.last_processed_at).to be_within(1.second).of(ts)
    end
  end
end
