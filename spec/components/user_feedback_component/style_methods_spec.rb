# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackComponent, type: :component do
  include_context "as member"

  let(:user) { create(:user) }

  def component(user = self.user, style: :badge)
    described_class.new(user: user, style: style)
  end

  describe "#badge_style?" do
    it "returns true when style is :badge" do
      expect(component(style: :badge).send(:badge_style?)).to be true
    end

    it "returns false when style is :inline" do
      expect(component(style: :inline).send(:badge_style?)).to be false
    end
  end

  describe "#inline_style?" do
    it "returns true when style is :inline" do
      expect(component(style: :inline).send(:inline_style?)).to be true
    end

    it "returns false when style is :badge" do
      expect(component(style: :badge).send(:inline_style?)).to be false
    end

    it "returns true when initialized with nil style (coerced to :inline)" do
      expect(component(style: nil).send(:inline_style?)).to be true
    end

    it "returns true when initialized with an invalid style (coerced to :inline)" do
      expect(component(style: "invalid").send(:inline_style?)).to be true
    end
  end
end
