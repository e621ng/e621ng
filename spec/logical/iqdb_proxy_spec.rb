# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbProxy do
  let(:mock_response) { instance_double(Faraday::Response, status: 200, body: "[]") }

  before do
    allow(described_class).to receive(:make_request).and_return(mock_response)
    allow(Cache.redis).to receive_messages(incr: 1, eval: 0, exists?: false)
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

  describe "circuit breaker" do
    describe ".query_hash" do
      context "when the circuit is open" do
        before { allow(Cache.redis).to receive(:exists?).with(IqdbProxy::CIRCUIT_OPEN_KEY).and_return(true) }

        it "raises CircuitOpenError without calling IQDB" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::CircuitOpenError)
          expect(described_class).not_to have_received(:make_request)
        end
      end

      context "when make_request raises an error" do
        before { allow(described_class).to receive(:make_request).and_raise(IqdbProxy::Error, "network failure") }

        it "records a circuit failure" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::Error)
          expect(Cache.redis).to have_received(:eval).with(IqdbProxy::INCR_WITH_EXPIRY,
                                                           keys: [IqdbProxy::CIRCUIT_FAILURES_KEY],
                                                           argv: [Danbooru.config.iqdb_circuit_failure_window])
        end
      end

      context "when IQDB returns a non-200 response" do
        let(:failing_response) { instance_double(Faraday::Response, status: 503, body: "") }

        before { allow(described_class).to receive(:make_request).and_return(failing_response) }

        it "records a circuit failure" do
          described_class.query_hash("deadbeef", 60)
          expect(Cache.redis).to have_received(:eval).with(IqdbProxy::INCR_WITH_EXPIRY,
                                                           keys: [IqdbProxy::CIRCUIT_FAILURES_KEY],
                                                           argv: [Danbooru.config.iqdb_circuit_failure_window])
        end
      end

      context "when the failure threshold is reached" do
        before do
          allow(described_class).to receive(:make_request).and_raise(IqdbProxy::Error, "network failure")
          allow(Cache.redis).to receive(:eval)
            .with(IqdbProxy::INCR_WITH_EXPIRY, anything)
            .and_return(Danbooru.config.iqdb_circuit_failure_threshold)
          allow(Cache.redis).to receive(:set).and_return(true)
          allow(Cache.redis).to receive(:del)
        end

        it "opens the circuit" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::Error)
          expect(Cache.redis).to have_received(:set).with(
            IqdbProxy::CIRCUIT_OPEN_KEY,
            anything,
            ex: Danbooru.config.iqdb_circuit_cooldown,
            nx: true,
          )
        end

        it "does not open the circuit if it is already open" do
          allow(Cache.redis).to receive(:exists?).with(IqdbProxy::CIRCUIT_OPEN_KEY).and_return(true)
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::CircuitOpenError)
          expect(Cache.redis).not_to have_received(:set).with(IqdbProxy::CIRCUIT_OPEN_KEY, anything, anything)
        end

        it "clears the failure counter after opening" do
          expect { described_class.query_hash("deadbeef", 60) }.to raise_error(IqdbProxy::Error)
          expect(Cache.redis).to have_received(:del).with(IqdbProxy::CIRCUIT_FAILURES_KEY)
        end
      end
    end

    describe ".query_file" do
      context "when the circuit is open" do
        before { allow(Cache.redis).to receive(:exists?).with(IqdbProxy::CIRCUIT_OPEN_KEY).and_return(true) }

        it "raises CircuitOpenError without calling IQDB" do
          fake_file = instance_double(File, path: "/tmp/fake.jpg")
          expect { described_class.query_file(fake_file, 60) }.to raise_error(IqdbProxy::CircuitOpenError)
          expect(described_class).not_to have_received(:make_request)
        end
      end
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
