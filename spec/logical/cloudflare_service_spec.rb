# frozen_string_literal: true

require "rails_helper"

RSpec.describe CloudflareService do
  let(:conn) { instance_double(Faraday::Connection) }

  before do
    allow(Faraday).to receive(:new).and_return(conn)
    Cache.delete("cloudflare_ips")
  end

  describe ".ips" do
    context "when the Cloudflare API returns 200" do
      let(:body) do
        {
          result: {
            ipv4_cidrs: ["103.21.244.0/22", "103.22.200.0/22"],
            ipv6_cidrs: ["2400:cb00::/32"],
          },
        }.to_json
      end

      before do
        allow(conn).to receive(:get).and_return(
          instance_double(Faraday::Response, body: body, status: 200),
        )
      end

      it "returns an array of IPAddr objects covering both IPv4 and IPv6 ranges" do
        ips = described_class.ips
        expect(ips).to all(be_a(IPAddr))
        expect(ips).to include(IPAddr.new("103.21.244.0/22"), IPAddr.new("103.22.200.0/22"), IPAddr.new("2400:cb00::/32"))
      end

      it "only calls the API once on repeated invocations" do
        described_class.ips
        described_class.ips
        expect(conn).to have_received(:get).once
      end
    end

    context "when the Cloudflare API returns a non-200 status" do
      before do
        allow(conn).to receive(:get).and_return(
          instance_double(Faraday::Response, body: "", status: 503),
        )
      end

      it "returns an empty array" do
        expect(described_class.ips).to eq([])
      end
    end
  end
end
