# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         IpBan Instance Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe IpBan do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #has_subnet?
  # ---------------------------------------------------------------------------
  describe "#has_subnet?" do
    it "returns true for an IPv4 address with a prefix shorter than /32" do
      ban = build(:ip_ban, ip_addr: "1.2.3.0/24")
      expect(ban.has_subnet?).to be true
    end

    it "returns false for an IPv4 host address (/32)" do
      ban = build(:ip_ban, ip_addr: "1.2.3.4")
      expect(ban.has_subnet?).to be false
    end

    it "returns true for an IPv6 address with a prefix shorter than /128" do
      ban = build(:ip_ban, ip_addr: "2001:db8::/64")
      expect(ban.has_subnet?).to be true
    end

    it "returns false for an IPv6 host address (/128)" do
      ban = build(:ip_ban, ip_addr: "2001:db8::1")
      expect(ban.has_subnet?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #subnetted_ip
  # ---------------------------------------------------------------------------
  describe "#subnetted_ip" do
    it "includes the prefix for an IPv4 subnet" do
      ban = build(:ip_ban, ip_addr: "1.2.3.0/24")
      expect(ban.subnetted_ip).to eq("1.2.3.0/24")
    end

    it "returns just the IP string for an IPv4 host address" do
      ban = build(:ip_ban, ip_addr: "1.2.3.4")
      expect(ban.subnetted_ip).to eq("1.2.3.4")
    end

    it "includes the prefix for an IPv6 subnet" do
      ban = build(:ip_ban, ip_addr: "2001:db8::/64")
      expect(ban.subnetted_ip).to include("/64")
    end

    it "returns just the IP string for an IPv6 host address" do
      ban = build(:ip_ban, ip_addr: "2001:db8::1")
      expect(ban.subnetted_ip).not_to include("/")
    end
  end
end
