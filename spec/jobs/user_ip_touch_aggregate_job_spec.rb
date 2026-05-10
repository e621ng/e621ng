# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpTouchAggregateJob do
  def perform
    described_class.perform_now
  end

  describe "#perform" do
    it "creates a cursor with cutoff_at = 5.years.ago on first run" do
      Timecop.freeze do
        perform
        cursor = UserIpTouchCursor.find_by(source: "comment")
        expect(cursor).not_to be_nil
        expect(cursor.cutoff_at).to be_within(1.second).of(5.years.ago)
      end
    end

    it "ingests a recent comment into user_ip_touches" do
      user = create(:user)
      comment = create(:comment, creator: user, creator_ip_addr: "10.0.0.10")
      perform
      touch = UserIpTouch.find_by(user_id: user.id, ip_addr: "10.0.0.10", source: "comment")
      expect(touch).not_to be_nil
      expect(touch.hit_count).to be >= 1
      expect(UserIpTouchCursor.find_by(source: "comment").last_processed_id).to be >= comment.id
    end

    it "skips rows with a null ip_addr" do
      create(:user, last_ip_addr: nil, last_logged_in_at: 1.day.ago)
      perform
      expect(UserIpTouch.where(source: "login")).to be_empty
    end

    it "is idempotent on a second run with no new rows" do
      user = create(:user)
      create(:comment, creator: user, creator_ip_addr: "10.0.0.11")
      perform
      expect { perform }.not_to change(UserIpTouch, :count)
    end

    it "updates ip_addr_stats with distinct_user_count for ingested IPs" do
      u1 = create(:user)
      u2 = create(:user)
      create(:comment, creator: u1, creator_ip_addr: "10.0.0.12")
      create(:comment, creator: u2, creator_ip_addr: "10.0.0.12")
      perform
      stat = IpAddrStat.find_by(ip_addr: "10.0.0.12")
      expect(stat.distinct_user_count).to eq(2)
    end
  end
end
