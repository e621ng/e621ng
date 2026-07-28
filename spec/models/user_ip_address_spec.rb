# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpAddress do
  include_context "as member"

  let(:user) { create(:user) }

  describe "the generated subnet column" do
    it "masks IPv4 to a /24" do
      record = create(:user_ip_address, user: user, ip_addr: "203.0.113.77")
      expect(record.reload.subnet.to_s).to eq("203.0.113.0")
      expect(record.subnet.prefix).to eq(24)
    end

    it "masks IPv6 to a /64" do
      record = create(:user_ip_address, user: user, ip_addr: "2001:db8:abcd:1234:aaaa:bbbb:cccc:dddd")
      expect(record.reload.subnet.to_s).to eq("2001:db8:abcd:1234::")
      expect(record.subnet.prefix).to eq(64)
    end
  end

  describe "uniqueness" do
    it "rejects a duplicate (user_id, ip_addr) at the database level" do
      create(:user_ip_address, user: user, ip_addr: "203.0.113.77")
      expect do
        create(:user_ip_address, user: user, ip_addr: "203.0.113.77")
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same IP for different users" do
      other = create(:user)
      create(:user_ip_address, user: user, ip_addr: "203.0.113.77")
      expect do
        create(:user_ip_address, user: other, ip_addr: "203.0.113.77")
      end.to change(described_class, :count).by(1)
    end
  end

  describe "#hidden_attributes" do
    it "hides both ip_addr and the derived subnet from JSON" do
      record = create(:user_ip_address, user: user, ip_addr: "203.0.113.77")
      json = record.as_json
      expect(json).not_to have_key("ip_addr")
      expect(json).not_to have_key("subnet")
    end
  end
end
