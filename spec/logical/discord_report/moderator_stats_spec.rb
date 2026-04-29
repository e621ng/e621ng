# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscordReport::ModeratorStats do
  let(:redis_double) { instance_spy(Redis) }

  before do
    allow(Cache).to receive(:redis).and_return(redis_double)
    allow(redis_double).to receive(:get).and_return(nil)
  end

  describe "#report" do
    it "returns a string without raising" do
      expect(described_class.new.report).to be_a(String)
    end
  end
end
