# frozen_string_literal: true

require "rails_helper"

RSpec.describe IpAddrStat do
  let(:u1) { create(:user) }
  let(:u2) { create(:user) }
  let(:u3) { create(:user) }

  def touch(user, ip, source: "comment", at: 1.day.ago)
    UserIpTouch.record_touches!([{
      user_id: user.id, ip_addr: ip, source: source, last_seen_at: at, hit_count: 1,
    }])
  end

  describe ".recompute_for!" do
    it "is a no-op for an empty array" do
      expect { described_class.recompute_for!([]) }.not_to change(described_class, :count)
    end

    it "creates a row with the distinct user count" do
      touch(u1, "10.0.0.5")
      touch(u2, "10.0.0.5")
      described_class.recompute_for!(["10.0.0.5"])
      stat = described_class.find("10.0.0.5")
      expect(stat.distinct_user_count).to eq(2)
    end

    it "counts the same user once across sources" do
      touch(u1, "10.0.0.6", source: "comment")
      touch(u1, "10.0.0.6", source: "post")
      described_class.recompute_for!(["10.0.0.6"])
      stat = described_class.find("10.0.0.6")
      expect(stat.distinct_user_count).to eq(1)
    end

    it "updates an existing row in place on re-run" do
      touch(u1, "10.0.0.7")
      described_class.recompute_for!(["10.0.0.7"])
      touch(u2, "10.0.0.7")
      touch(u3, "10.0.0.7")
      described_class.recompute_for!(["10.0.0.7"])
      stat = described_class.find("10.0.0.7")
      expect(stat.distinct_user_count).to eq(3)
    end

    it "stores the maximum last_seen_at across touches" do
      newest = 1.hour.ago
      touch(u1, "10.0.0.8", at: 30.days.ago)
      touch(u2, "10.0.0.8", at: newest)
      described_class.recompute_for!(["10.0.0.8"])
      stat = described_class.find("10.0.0.8")
      expect(stat.last_seen_at).to be_within(1.second).of(newest)
    end
  end
end
