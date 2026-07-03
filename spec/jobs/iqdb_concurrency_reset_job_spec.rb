# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbConcurrencyResetJob do
  describe "#perform" do
    context "when IQDB counter keys exist" do
      before do
        allow(Cache.redis).to receive(:smembers).with("iqdb:concurrent:keys")
                                                .and_return(["iqdb:concurrent:e621", "iqdb:concurrent:e926"])
        allow(Cache.redis).to receive(:del)
      end

      it "deletes all matching keys" do
        described_class.perform_now
        expect(Cache.redis).to have_received(:del).with("iqdb:concurrent:e621", "iqdb:concurrent:e926")
        expect(Cache.redis).to have_received(:del).with("iqdb:concurrent:keys")
      end
    end

    context "when no IQDB counter keys exist" do
      before do
        allow(Cache.redis).to receive(:smembers).with("iqdb:concurrent:keys").and_return([])
        allow(Cache.redis).to receive(:del)
      end

      it "does not call DEL" do
        described_class.perform_now
        expect(Cache.redis).not_to have_received(:del)
      end
    end
  end
end
