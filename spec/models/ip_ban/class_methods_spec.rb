# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          IpBan Class Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe IpBan do
  include_context "as moderator"

  # ---------------------------------------------------------------------------
  # .is_banned?
  # ---------------------------------------------------------------------------
  describe ".is_banned?" do
    it "returns true when the exact IP address has been banned" do
      create(:ip_ban, ip_addr: "1.2.3.4")
      expect(IpBan.is_banned?("1.2.3.4")).to be true
    end

    it "returns true when the queried IP falls within a banned subnet" do
      create(:ip_ban, ip_addr: "1.2.3.0/24")
      expect(IpBan.is_banned?("1.2.3.100")).to be true
    end

    it "returns false when no ban covers the queried IP" do
      create(:ip_ban, ip_addr: "1.2.3.4")
      expect(IpBan.is_banned?("5.6.7.8")).to be false
    end

    it "returns false when no bans exist at all" do
      expect(IpBan.is_banned?("1.2.3.4")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # .search
  # ---------------------------------------------------------------------------
  describe ".search" do
    # Use distinct public IPs so the uniqueness constraint is satisfied.
    let!(:ban_a) { create(:ip_ban, ip_addr: "1.2.3.4",   reason: "spam bot") }
    let!(:ban_b) { create(:ip_ban, ip_addr: "5.6.7.8",   reason: "credential stuffing") }

    # ip_addr param uses the >>= subnet-containment operator
    describe "ip_addr param" do
      it "returns the ban whose address matches the queried IP" do
        result = IpBan.search(ip_addr: "1.2.3.4")
        expect(result).to include(ban_a)
        expect(result).not_to include(ban_b)
      end
    end

    # reason param delegates to attribute_matches (supports wildcards)
    describe "reason param" do
      it "filters by exact reason string" do
        expect(IpBan.search(reason: "spam bot")).to include(ban_a)
        expect(IpBan.search(reason: "spam bot")).not_to include(ban_b)
      end

      it "supports wildcard matching" do
        expect(IpBan.search(reason: "spam*")).to include(ban_a)
        expect(IpBan.search(reason: "spam*")).not_to include(ban_b)
      end
    end

    # banner_id filters by the creator (where_user(:creator_id, :banner, params))
    describe "banner_id param" do
      it "filters bans by the creator's id" do
        other_mod = create(:moderator_user)
        ban_c = create(:ip_ban, creator: other_mod, ip_addr: "9.9.9.9")

        result = IpBan.search(banner_id: other_mod.id)
        expect(result).to include(ban_c)
        expect(result).not_to include(ban_a, ban_b)
      end
    end

    # ordering
    describe "order param" do
      it "returns records newest-first by default (id descending)" do
        ids = IpBan.search({}).ids
        expect(ids.index(ban_b.id)).to be < ids.index(ban_a.id)
      end

      it "returns records oldest-first with order: id_asc" do
        ids = IpBan.search(order: "id_asc").ids
        expect(ids.index(ban_a.id)).to be < ids.index(ban_b.id)
      end
    end
  end
end
