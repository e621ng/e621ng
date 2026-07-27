# frozen_string_literal: true

require "rails_helper"

RSpec.describe AsnRange do
  describe ".lookup" do
    context "with ranges loaded" do
      before do
        create(:asn_range, first_ip: "198.51.100.0", last_ip: "198.51.100.127", asn: 64_496, name: "EXAMPLE-NET-2", country: "None")
        create(:asn_range, first_ip: "203.0.113.0", last_ip: "203.0.113.255", asn: 64_500, name: "EXAMPLE-NET-3", country: "US")
        create(:asn_range, first_ip: "2001:db8::", last_ip: "2001:db8::ffff", asn: 64_501, name: "EXAMPLE-V6", country: "FR")
      end

      it "resolves an IPv4 address inside a range" do
        expect(described_class.lookup(["203.0.113.5"])).to eq("203.0.113.5" => { asn: 64_500, name: "EXAMPLE-NET-3", country: "US" })
      end

      it "resolves an IPv6 address inside a range" do
        expect(described_class.lookup(["2001:db8::1"])).to eq("2001:db8::1" => { asn: 64_501, name: "EXAMPLE-V6", country: "FR" })
      end

      it "returns nil for an address in a gap between ranges" do
        expect(described_class.lookup(["198.51.100.200"])).to eq("198.51.100.200" => nil)
      end

      it "returns nil for an address below all ranges" do
        expect(described_class.lookup(["1.2.3.4"])).to eq("1.2.3.4" => nil)
      end

      it "returns nil for an IPv6 address below all IPv6 ranges" do
        # The candidate row here is the topmost IPv4 range; its IPv4 last_ip
        # can never contain an IPv6 address, so the containment check rejects it.
        expect(described_class.lookup(["100::1"])).to eq("100::1" => nil)
      end

      it "returns a key for every input in a mixed batch" do
        result = described_class.lookup(["203.0.113.5", "1.2.3.4", "127.0.0.1"])
        expect(result.keys).to contain_exactly("203.0.113.5", "1.2.3.4", "127.0.0.1")
        expect(result["203.0.113.5"]).to include(asn: 64_500)
        expect(result["1.2.3.4"]).to be_nil
        expect(result["127.0.0.1"]).to be_nil
      end

      it "accepts IPAddr objects and normalizes keys to strings" do
        expect(described_class.lookup([IPAddr.new("203.0.113.5")])).to eq("203.0.113.5" => { asn: 64_500, name: "EXAMPLE-NET-3", country: "US" })
      end

      it "drops unparseable input" do
        expect(described_class.lookup(["not-an-ip"])).to eq({})
      end
    end

    context "with a range covering reserved space" do
      before do
        create(:asn_range, first_ip: "0.0.0.0", last_ip: "255.255.255.255", asn: 64_512, name: "EVERYTHING")
      end

      it "still returns nil for private, loopback, and link-local addresses" do
        expect(described_class.lookup(["10.0.0.1", "127.0.0.1", "169.254.0.1", "::1"]).values).to all(be_nil)
        expect(described_class.lookup(["8.8.8.8"])["8.8.8.8"]).to include(asn: 64_512)
      end
    end

    context "with an empty table" do
      it "returns nil for everything" do
        expect(described_class.lookup(["203.0.113.5", "2001:db8::1"])).to eq("203.0.113.5" => nil, "2001:db8::1" => nil)
      end
    end
  end

  describe ".replace_all!" do
    it "replaces the existing rows" do
      create(:asn_range, asn: 1)
      described_class.replace_all!([{ first_ip: "203.0.113.0", last_ip: "203.0.113.255", asn: 2, name: "NEW", country: "" }])
      expect(described_class.pluck(:asn)).to eq([2])
    end

    it "leaves the old rows intact when an insert fails" do
      stub_const("AsnRange::INSERT_BATCH_SIZE", 1)
      create(:asn_range, asn: 1)
      rows = [
        { first_ip: "203.0.113.0", last_ip: "203.0.113.255", asn: 2, name: "A", country: "" },
        { first_ip: "198.51.100.0", last_ip: "198.51.100.255", asn: 3, name: "B", country: "" },
      ]
      calls = 0
      allow(described_class).to receive(:insert_all).and_wrap_original do |original, *args|
        calls += 1
        raise ActiveRecord::StatementInvalid, "boom" if calls == 2

        original.call(*args)
      end

      expect { described_class.replace_all!(rows) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(described_class.pluck(:asn)).to eq([1])
    end
  end
end
