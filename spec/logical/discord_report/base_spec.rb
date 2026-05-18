# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscordReport::Base do
  let(:concrete_class) do
    Class.new(described_class) do
      def webhook_url = "https://example.com/webhook"
      def report = "test report"
    end
  end
  let(:instance) { concrete_class.new }

  describe "#webhook_url" do
    it "raises NotImplementedError on the base class" do
      expect { described_class.new.webhook_url }.to raise_error(NotImplementedError)
    end
  end

  describe "#report" do
    it "raises NotImplementedError on the base class" do
      expect { described_class.new.report }.to raise_error(NotImplementedError)
    end
  end

  describe "#run!" do
    it "does nothing when webhook_url is blank" do
      allow(instance).to receive(:webhook_url).and_return(nil)
      expect { instance.run! }.not_to raise_error
    end

    it "posts to the webhook when webhook_url is present" do
      conn = instance_double(Faraday::Connection)
      allow(Faraday).to receive(:new).and_return(conn)
      allow(conn).to receive(:post)
      instance.run!
      expect(conn).to have_received(:post)
    end
  end

  describe "#formatted_number" do
    it "wraps the number in bold markdown with thousand delimiters" do
      expect(instance.formatted_number(1_234_567)).to eq("**1,234,567**")
    end
  end

  describe "#more_fewer" do
    it "returns 'more' for a positive diff" do
      expect(instance.more_fewer(5)).to eq("**5** more")
    end

    it "returns 'fewer' for a negative diff" do
      expect(instance.more_fewer(-3)).to eq("**3** fewer")
    end

    it "uses the absolute value in the label" do
      expect(instance.more_fewer(-100)).to eq("**100** fewer")
    end
  end
end
