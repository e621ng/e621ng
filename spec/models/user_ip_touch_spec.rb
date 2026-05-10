# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpTouch do
  let(:user) { create(:user) }

  describe ".record_touches!" do
    let(:base_row) do
      {
        user_id:      user.id,
        ip_addr:      "10.0.0.1",
        source:       "comment",
        last_seen_at: 2.days.ago,
        hit_count:    1,
      }
    end

    it "is a no-op for an empty array" do
      expect { described_class.record_touches!([]) }.not_to change(described_class, :count)
    end

    it "inserts new rows" do
      expect { described_class.record_touches!([base_row]) }
        .to change(described_class, :count).by(1)
    end

    it "increments hit_count on conflict" do
      described_class.record_touches!([base_row.merge(hit_count: 5)])
      described_class.record_touches!([base_row.merge(hit_count: 3, last_seen_at: 1.hour.ago)])
      row = described_class.find_by(user_id: user.id, ip_addr: "10.0.0.1", source: "comment")
      expect(row.hit_count).to eq(8)
    end

    it "advances last_seen_at to GREATEST(existing, incoming)" do
      newer = 1.hour.ago
      older = 30.days.ago
      described_class.record_touches!([base_row.merge(last_seen_at: newer)])
      described_class.record_touches!([base_row.merge(last_seen_at: older)])
      row = described_class.find_by(user_id: user.id, ip_addr: "10.0.0.1", source: "comment")
      expect(row.last_seen_at).to be_within(1.second).of(newer)
    end

    it "treats different sources as distinct rows for the same (user, ip)" do
      described_class.record_touches!([base_row.merge(source: "comment"), base_row.merge(source: "post")])
      expect(described_class.where(user_id: user.id, ip_addr: "10.0.0.1").count).to eq(2)
    end
  end
end
