# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserAltFinder do
  include_context "as admin"

  let(:now) { Time.now }

  # A shared window wide enough for full dwell weight and overlapping enough for
  # full proximity, so scores land in a realistic band.
  def seen(user, ip, first: 40.days.ago, last: 2.days.ago, hits: 10)
    create(:user_ip_address, user: user, ip_addr: ip, first_seen_at: first, last_seen_at: last, hit_count: hits)
  end

  describe "#candidates" do
    it "ranks an exact-IP alt above a subnet-only stranger" do
      target   = create(:user)
      alt      = create(:user)
      stranger = create(:user)

      seen(target, "203.0.113.10")
      seen(alt, "203.0.113.10")            # exact IP shared with target
      seen(target, "198.51.100.5")
      seen(stranger, "198.51.100.200")     # same /24 as the target only

      candidates = described_class.new(target).candidates
      ids = candidates.pluck(:user_id)

      expect(ids).to include(alt.id, stranger.id)
      expect(candidates.first[:user_id]).to eq(alt.id)

      alt_score = candidates.find { |c| c[:user_id] == alt.id }[:score]
      stranger_score = candidates.find { |c| c[:user_id] == stranger.id }[:score]
      expect(alt_score).to be > stranger_score
    end

    it "drops values shared by more than the crowded cutoffs" do
      # Users colliding on one exact IP necessarily share its /24 too, so both
      # cutoffs must be lowered for the collision to be fully discarded.
      allow(Danbooru.config.custom_configuration).to receive_messages(alt_finder_max_users_per_ip: 2, alt_finder_max_users_per_subnet: 2)
      target = create(:user)
      crowd = create_list(:user, 3)

      seen(target, "203.0.113.50")
      crowd.each { |u| seen(u, "203.0.113.50") } # 4 distinct users on this IP/subnet (> 2)

      ids = described_class.new(target).candidates.pluck(:user_id)
      expect(ids).not_to include(*crowd.map(&:id))
    end

    it "includes deleted accounts, flagged as such" do
      target = create(:user)
      alt = create(:user)
      alt.update_columns(name: "user_#{alt.id}")

      seen(target, "203.0.113.60")
      seen(alt, "203.0.113.60")

      candidate = described_class.new(target).candidates.find { |c| c[:user_id] == alt.id }
      expect(candidate).to be_present
      expect(candidate[:deleted]).to be(true)
    end

    it "flags collision-renamed deleted accounts (user_{id}_{n})" do
      target = create(:user)
      alt = create(:user)
      alt.update_columns(name: "user_#{alt.id}_1")

      seen(target, "203.0.113.65")
      seen(alt, "203.0.113.65")

      candidate = described_class.new(target).candidates.find { |c| c[:user_id] == alt.id }
      expect(candidate[:deleted]).to be(true)
    end

    it "does not double-count an exact match's own subnet as subnet-only evidence" do
      target = create(:user)
      alt = create(:user)

      # The two accounts share exactly one IP and nothing else. Its /24 is not
      # separate evidence — the exact match already covers that network.
      seen(target, "203.0.113.80")
      seen(alt, "203.0.113.80")

      candidate = described_class.new(target).candidates.find { |c| c[:user_id] == alt.id }
      expect(candidate[:shared_exact]).to eq(1)
      expect(candidate[:shared_subnet]).to eq(0)
    end

    it "measures the candidate's IP total within the same window as the target" do
      target = create(:user)
      alt = create(:user)
      seen(target, "203.0.113.90")
      seen(alt, "203.0.113.90") # recent shared IP, inside the window
      # A stale row beyond the retention window that the prune job hasn't reached
      # yet must not inflate the ratio denominator.
      create(:user_ip_address, user: alt, ip_addr: "198.51.100.90",
                               first_seen_at: 4.years.ago, last_seen_at: 3.years.ago)

      candidate = described_class.new(target).candidates.find { |c| c[:user_id] == alt.id }
      expect(candidate[:total_ips]).to eq(1)
    end

    it "flags the handoff pattern" do
      target = create(:user, created_at: 90.days.ago)
      # A fresh account that took over the IP right after the target left it.
      alt = create(:user, created_at: 6.days.ago)

      seen(target, "203.0.113.70", first: 40.days.ago, last: 8.days.ago)
      seen(alt, "203.0.113.70", first: 5.days.ago, last: 1.day.ago)

      candidate = described_class.new(target).candidates.find { |c| c[:user_id] == alt.id }
      expect(candidate[:handoff]).to be(true)
    end
  end

  describe "#chains" do
    it "surfaces an indirect account reachable only through a shared predecessor" do
      a = create(:user)
      b = create(:user)
      c = create(:user)

      seen(a, "203.0.113.10")   # A <-> B on this IP
      seen(b, "203.0.113.10")
      seen(b, "198.51.100.10")  # B <-> C on a different IP
      seen(c, "198.51.100.10")

      finder = described_class.new(a)
      direct_ids = finder.candidates.pluck(:user_id)
      expect(direct_ids).to include(b.id)
      expect(direct_ids).not_to include(c.id) # A and C never shared an IP

      via_b = finder.chains.find { |chain| chain[:via][:user_id] == b.id }
      expect(via_b).to be_present
      expect(via_b[:candidates].pluck(:user_id)).to include(c.id)
    end
  end
end
