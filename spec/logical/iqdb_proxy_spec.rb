# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbProxy do
  let(:mock_response) { instance_double(Faraday::Response, status: 200, body: "[]") }

  before do
    allow(described_class).to receive(:make_request).and_return(mock_response)
    allow(Cache.redis).to receive_messages(incr: 1, eval: 0)
  end

  describe ".redis_key" do
    it "returns the base key when server_name is not configured" do
      expect(described_class.redis_key).to eq("iqdb:concurrent")
    end

    it "includes server_name when configured" do
      allow(Danbooru.config.custom_configuration).to receive(:server_name).and_return("e621")
      expect(described_class.redis_key).to eq("iqdb:concurrent:e621")
    end
  end

  describe "concurrency semaphore" do
    describe ".query_hash" do
      it "increments the Redis counter before querying IQDB" do
        described_class.query_hash("deadbeef", 60)
        expect(Cache.redis).to have_received(:incr).with(described_class.redis_key)
      end

      it "decrements the counter after a successful query" do
        described_class.query_hash("deadbeef", 60)
        expect(Cache.redis).to have_received(:eval).with(IqdbProxy::DECR_FLOOR_ZERO, keys: [described_class.redis_key])
      end

      it "decrements the counter when the query raises an error" do
        allow(described_class).to receive(:make_request).and_raise(IqdbProxy::Error, "unavailable")
        expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::Error)
        expect(Cache.redis).to have_received(:eval).with(IqdbProxy::DECR_FLOOR_ZERO, keys: [described_class.redis_key])
      end

      context "when the concurrency cap is exhausted" do
        before { allow(Cache.redis).to receive(:incr).and_return(Danbooru.config.iqdb_max_concurrent_queries + 1) }

        it "raises BusyError" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::BusyError)
        end

        it "does not call IQDB" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::BusyError)
          expect(described_class).not_to have_received(:make_request)
        end

        it "decrements the counter without yielding" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::BusyError)
          expect(Cache.redis).to have_received(:eval).with(IqdbProxy::DECR_FLOOR_ZERO, keys: [described_class.redis_key])
        end
      end
    end
  end
end
