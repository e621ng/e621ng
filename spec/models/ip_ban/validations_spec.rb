# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            IpBan Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe IpBan do
  let(:moderator) { create(:moderator_user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "validations" do
    # -------------------------------------------------------------------------
    # reason
    # -------------------------------------------------------------------------
    describe "reason" do
      it "is invalid without a reason" do
        record = build(:ip_ban, reason: nil)
        expect(record).not_to be_valid
        expect(record.errors[:reason]).to be_present
      end

      it "is invalid with a blank reason" do
        record = build(:ip_ban, reason: "")
        expect(record).not_to be_valid
        expect(record.errors[:reason]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # ip_addr presence
    # -------------------------------------------------------------------------
    describe "ip_addr presence" do
      it "is invalid without an ip_addr" do
        record = build(:ip_ban, ip_addr: nil)
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # ip_addr uniqueness
    # -------------------------------------------------------------------------
    describe "ip_addr uniqueness" do
      it "is invalid when an ip ban for the same address already exists" do
        create(:ip_ban, ip_addr: "1.2.3.4")
        record = build(:ip_ban, ip_addr: "1.2.3.4")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # validate_ip_addr — IPv4 subnet size
    # -------------------------------------------------------------------------
    describe "IPv4 subnet size" do
      it "is invalid when the subnet is broader than /24 (e.g. /23)" do
        record = build(:ip_ban, ip_addr: "1.2.2.0/23")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("may not have a subnet bigger than /24")
      end

      it "is valid at exactly /24 (the minimum allowed subnet)" do
        expect(build(:ip_ban, ip_addr: "1.2.3.0/24")).to be_valid
      end

      it "is valid for a host address (/32)" do
        expect(build(:ip_ban, ip_addr: "1.2.3.4")).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validate_ip_addr — IPv6 subnet size
    # -------------------------------------------------------------------------
    describe "IPv6 subnet size" do
      it "is invalid when the subnet is broader than /64 (e.g. /63)" do
        record = build(:ip_ban, ip_addr: "2001:db8::/63")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("may not have a subnet bigger than /64")
      end

      it "is valid at exactly /64 (the minimum allowed subnet)" do
        expect(build(:ip_ban, ip_addr: "2001:db8::/64")).to be_valid
      end

      it "is valid for a host address (/128)" do
        expect(build(:ip_ban, ip_addr: "2001:db8::1")).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validate_ip_addr — address type restrictions
    # -------------------------------------------------------------------------
    describe "address type restrictions" do
      it "is invalid for a private IPv4 address" do
        record = build(:ip_ban, ip_addr: "10.0.0.1")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("must be a public address")
      end

      it "is invalid for another private range (172.16.0.0/12)" do
        record = build(:ip_ban, ip_addr: "172.16.0.1")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("must be a public address")
      end

      it "is invalid for a loopback address" do
        record = build(:ip_ban, ip_addr: "127.0.0.1")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("must be a public address")
      end

      it "is invalid for a link-local address" do
        record = build(:ip_ban, ip_addr: "169.254.1.1")
        expect(record).not_to be_valid
        expect(record.errors[:ip_addr]).to include("must be a public address")
      end

      it "is valid for a public IPv4 address" do
        expect(build(:ip_ban, ip_addr: "8.8.8.8")).to be_valid
      end
    end
  end
end
