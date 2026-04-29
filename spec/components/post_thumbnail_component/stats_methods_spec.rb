# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#shortened_value" do
    subject(:c) { component(post) }

    it "returns '0' for nil" do
      expect(c.send(:shortened_value, nil)).to eq("0")
    end

    it "returns '0' for 0" do
      expect(c.send(:shortened_value, 0)).to eq("0")
    end

    it "returns the number as a string for small values" do
      expect(c.send(:shortened_value, 999)).to eq("999")
    end

    it "returns a k-suffix for values >= 1000" do
      expect(c.send(:shortened_value, 1000)).to eq("1.0k")
    end

    it "rounds to one decimal for k-suffix values" do
      expect(c.send(:shortened_value, 1500)).to eq("1.5k")
    end

    it "uses the absolute value for negatives" do
      expect(c.send(:shortened_value, -5)).to eq("5")
    end
  end

  describe "#score_icon" do
    it "returns :square_slash for a score of 0" do
      allow(post).to receive(:score).and_return(0)
      expect(component(post).send(:score_icon)).to eq(:square_slash)
    end

    it "returns :square_slash for a nil score" do
      allow(post).to receive(:score).and_return(nil)
      expect(component(post).send(:score_icon)).to eq(:square_slash)
    end

    it "returns :arrow_up_dash for a positive score" do
      allow(post).to receive(:score).and_return(10)
      expect(component(post).send(:score_icon)).to eq(:arrow_up_dash)
    end

    it "returns :arrow_down_dash for a negative score" do
      allow(post).to receive(:score).and_return(-3)
      expect(component(post).send(:score_icon)).to eq(:arrow_down_dash)
    end
  end

  describe "#score_class" do
    it "returns 'neutral' for a score of 0" do
      allow(post).to receive(:score).and_return(0)
      expect(component(post).send(:score_class)).to eq("neutral")
    end

    it "returns 'neutral' for a nil score" do
      allow(post).to receive(:score).and_return(nil)
      expect(component(post).send(:score_class)).to eq("neutral")
    end

    it "returns 'positive' for a positive score" do
      allow(post).to receive(:score).and_return(5)
      expect(component(post).send(:score_class)).to eq("positive")
    end

    it "returns 'negative' for a negative score" do
      allow(post).to receive(:score).and_return(-1)
      expect(component(post).send(:score_class)).to eq("negative")
    end
  end

  describe "#should_show_stats?" do
    it "returns false when stats: false option is given" do
      expect(component(post, stats: false).send(:should_show_stats?)).to be false
    end

    it "returns true when stats: true option is given" do
      expect(component(post, stats: true).send(:should_show_stats?)).to be true
    end

    it "delegates to user's show_post_statistics? when no stats option is given" do
      allow(CurrentUser.user).to receive(:show_post_statistics?).and_return(true)
      expect(component(post).send(:should_show_stats?)).to be true
    end

    it "returns false when no stats option and user has post statistics disabled" do
      allow(CurrentUser.user).to receive(:show_post_statistics?).and_return(false)
      expect(component(post).send(:should_show_stats?)).to be false
    end
  end
end
