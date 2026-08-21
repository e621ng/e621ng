# frozen_string_literal: true

require "rails_helper"

RSpec.describe RateLimiter do
  # The test environment uses a null cache store, which would make the limiter
  # inert; swap in a real store so counting and expiry behave like production.
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  let(:limiter) { described_class.new("spec", limit: 3, period: 1.minute) }

  describe "#hit!" do
    it "returns the count within the current window" do
      expect(limiter.hit!).to eq(1)
      expect(limiter.hit!).to eq(2)
    end

    it "does not extend the window (fixed window, not rolling)" do
      limiter.hit!
      travel 50.seconds
      limiter.hit!
      travel 11.seconds # 61s after the first hit: the window has expired
      expect(limiter.hit!).to eq(1)
    end
  end

  describe "#throttled?" do
    it "is false before the limit is reached" do
      2.times { limiter.hit! }
      expect(limiter).not_to be_throttled
    end

    it "is true once the limit is reached" do
      3.times { limiter.hit! }
      expect(limiter).to be_throttled
    end

    it "unthrottles once the window expires" do
      3.times { limiter.hit! }
      travel 61.seconds
      expect(limiter).not_to be_throttled
    end

    it "does not modify any state" do
      3.times { limiter.hit! }
      10.times { limiter.throttled? }
      travel 61.seconds
      expect(limiter).not_to be_throttled
    end
  end

  describe "lockout" do
    let(:limiter) { described_class.new("spec", limit: 2, period: 1.minute, lockout: 10.minutes) }

    it "keeps throttling after the window expires until the lockout ends" do
      2.times { limiter.hit! }
      travel 61.seconds
      expect(limiter).to be_throttled
      travel 10.minutes
      expect(limiter).not_to be_throttled
    end

    it "is not extended by hits made during the lockout" do
      2.times { limiter.hit! }
      travel 5.minutes
      limiter.hit!
      travel 5.minutes + 1.second
      expect(limiter).not_to be_throttled
    end
  end

  describe ".throttle!" do
    it "counts the attempt and allows it while under the limit" do
      expect(described_class.throttle!("spec", limit: 2, period: 1.minute)).to be(false)
      expect(described_class.throttle!("spec", limit: 2, period: 1.minute)).to be(false)
      expect(described_class.throttle!("spec", limit: 2, period: 1.minute)).to be(true)
    end

    it "does not count rejected attempts" do
      3.times { described_class.throttle!("spec", limit: 2, period: 1.minute) }
      travel 61.seconds
      expect(described_class.throttle!("spec", limit: 2, period: 1.minute)).to be(false)
    end
  end

  describe "#reset!" do
    it "clears the counter and any lockout" do
      lock = described_class.new("spec", limit: 1, period: 1.minute, lockout: 1.hour)
      lock.hit!
      expect(lock).to be_throttled
      lock.reset!
      expect(lock).not_to be_throttled
    end
  end
end
