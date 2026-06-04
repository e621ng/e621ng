# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscordReport::JanitorStats do
  include_context "as admin"

  let(:redis_double) { instance_spy(Redis) }

  before do
    allow(Cache).to receive(:redis).and_return(redis_double)
    allow(redis_double).to receive(:get).and_return(nil)
  end

  def make_deletion(deleter:, reason:)
    PostDeletion.create!(
      post: create(:post), deleter: deleter,
      creator_ip_addr: "127.0.0.1", reason: reason
    )
  end

  describe "#report" do
    it "returns a string without raising" do
      expect(described_class.new.report).to be_a(String)
    end
  end

  describe "#stats deletions" do
    it "counts deletions from post_deletions, splitting automod and takedowns" do
      make_deletion(deleter: create(:user), reason: "spam")
      make_deletion(deleter: User.system, reason: "spam")
      make_deletion(deleter: create(:user), reason: "takedown #5")

      expect(described_class.new.send(:stats)[:deletions]).to include(total: 3, automod: 1, takedowns: 1)
    end
  end
end
