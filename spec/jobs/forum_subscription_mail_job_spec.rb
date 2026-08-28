# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumSubscriptionMailJob do
  describe "#perform" do
    it "processes all forum subscriptions" do
      allow(ForumSubscription).to receive(:process_all!)

      described_class.new.perform

      expect(ForumSubscription).to have_received(:process_all!)
    end
  end
end
