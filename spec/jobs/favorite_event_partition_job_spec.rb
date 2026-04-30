# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteEventPartitionJob do
  describe "#perform" do
    it "ensures upcoming partitions and drops old ones" do
      allow(FavoriteEvent).to receive(:ensure_upcoming_partitions!)
      allow(FavoriteEvent).to receive(:drop_old_partitions!)
      described_class.perform_now
      expect(FavoriteEvent).to have_received(:ensure_upcoming_partitions!)
      expect(FavoriteEvent).to have_received(:drop_old_partitions!)
    end
  end
end
