# frozen_string_literal: true

require "rails_helper"

RSpec.describe AsnRangeImporter do
  let(:conn) { instance_double(Faraday::Connection) }
  let(:body) { file_fixture("ip2asn-combined.tsv.gz").binread }

  before do
    allow(Faraday).to receive(:new).and_return(conn)
    allow(conn).to receive(:get).and_return(instance_double(Faraday::Response, body: body, status: 200, success?: true))
  end

  describe ".parse" do
    it "returns a lazy enumerator rather than materializing all rows" do
      expect(described_class.parse(body)).to be_a(Enumerator)
    end
  end

  describe ".import!" do
    context "with the row count guard lowered" do
      before { stub_const("AsnRangeImporter::MINIMUM_ROW_COUNT", 3) }

      it "imports the routed ranges with the correct column mapping" do
        described_class.import!
        expect(AsnRange.count).to eq(3)
        range = AsnRange.find_by(asn: 64_500)
        expect(range.first_ip.to_s).to eq("203.0.113.0")
        expect(range.last_ip.to_s).to eq("203.0.113.255")
        expect(range.name).to eq("EXAMPLE-NET-3")
        expect(range.country).to eq("US")
      end

      it "normalizes the literal country \"None\" to an empty string" do
        described_class.import!
        expect(AsnRange.find_by(asn: 64_496).country).to eq("")
      end

      it "skips AS0 (unrouted) rows" do
        described_class.import!
        expect(AsnRange.where(first_ip: "192.0.2.0")).not_to exist
      end

      it "parses IPv6 ranges" do
        described_class.import!
        range = AsnRange.find_by(asn: 64_501)
        expect(range.first_ip.to_s).to eq("2001:db8::")
        expect(range.country).to eq("FR")
      end

      it "replaces previously imported rows" do
        create(:asn_range, asn: 1)
        described_class.import!
        expect(AsnRange.where(asn: 1)).not_to exist
      end
    end

    it "refuses to swap in a suspiciously small dataset" do
      create(:asn_range, asn: 1)
      expect { described_class.import! }.to raise_error(AsnRangeImporter::Error, /suspiciously small/)
      expect(AsnRange.pluck(:asn)).to eq([1])
    end

    context "when the data URL is not configured" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:ip_to_asn_data_url).and_return(nil)
      end

      it "does nothing" do
        create(:asn_range, asn: 1)
        described_class.import!
        expect(conn).not_to have_received(:get)
        expect(AsnRange.pluck(:asn)).to eq([1])
      end
    end

    context "when the download fails" do
      before do
        allow(conn).to receive(:get).and_return(instance_double(Faraday::Response, body: "", status: 503, success?: false))
      end

      it "raises and leaves the table untouched" do
        create(:asn_range, asn: 1)
        expect { described_class.import! }.to raise_error(AsnRangeImporter::Error, /HTTP 503/)
        expect(AsnRange.pluck(:asn)).to eq([1])
      end
    end
  end
end
