# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::AltLookup do
  let(:target)    { create(:user) }
  let(:candidate) { create(:user) }
  let(:other)     { create(:user) }

  before do
    Setting.alt_detection_enabled  = true
    Setting.alt_cgnat_threshold    = 50
    Setting.alt_strong_threshold   = 2.0
    Setting.alt_possible_threshold = 0.7
    Setting.alt_weak_floor         = 0.2
  end

  def touch(user, ip, source: "comment", at: 1.day.ago)
    UserIpTouch.record_touches!([{
      user_id: user.id, ip_addr: ip, source: source, last_seen_at: at, hit_count: 1,
    }])
    IpAddrStat.recompute_for!([ip])
  end

  describe "#execute" do
    it "returns [] when alt detection is disabled" do
      Setting.alt_detection_enabled = false
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      expect(described_class.new(target).execute).to eq([])
    end

    it "returns [] when the target has no touches" do
      expect(described_class.new(target).execute).to eq([])
    end

    it "excludes the target from the result set" do
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      result_ids = described_class.new(target).execute.map { |r| r[:user_id] }
      expect(result_ids).not_to include(target.id)
    end

    it "returns a candidate that shares an exclusive IP" do
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      result = described_class.new(target).execute
      ids = result.map { |r| r[:user_id] }
      expect(ids).to include(candidate.id)
    end

    it "excludes IPs above the CGNAT threshold" do
      Setting.alt_cgnat_threshold = 2
      # Three users on the same IP -> distinct_user_count = 3 -> excluded
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      touch(other, "10.0.0.1")
      expect(described_class.new(target).execute).to eq([])
    end

    it "drops candidates whose score falls below the weak floor" do
      Setting.alt_weak_floor       = 0.99
      Setting.alt_possible_threshold = 1.5
      Setting.alt_strong_threshold = 3.0
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      expect(described_class.new(target).execute).to eq([])
    end

    it "labels each result with a badge symbol and a date" do
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1", at: 3.days.ago)
      row = described_class.new(target).execute.first
      expect(row[:badge]).to be_a(Symbol)
      expect(row[:last_overlap_on]).to be_a(Date)
    end

    it "does not include a numeric score in the result rows" do
      touch(target, "10.0.0.1")
      touch(candidate, "10.0.0.1")
      row = described_class.new(target).execute.first
      expect(row.keys).to contain_exactly(:user_id, :badge, :last_overlap_on)
    end

    it "caps the result set at RESULT_CAP" do
      touch(target, "10.0.0.1")
      (described_class::RESULT_CAP + 5).times do
        u = create(:user)
        touch(u, "10.0.0.1")
      end
      expect(described_class.new(target).execute.size).to eq(described_class::RESULT_CAP)
    end
  end
end
