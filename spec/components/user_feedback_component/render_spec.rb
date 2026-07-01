# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackComponent, type: :component do
  include_context "as member"

  let(:user) { create(:user) }

  def component(user = self.user, style: :badge)
    described_class.new(user: user, style: style)
  end

  describe "#render?" do
    it "returns true when user is present and style is :badge" do
      expect(component(user, style: :badge).render?).to be true
    end

    it "returns true when user is present and style is :inline" do
      expect(component(user, style: :inline).render?).to be true
    end

    it "returns true when style is given as a string" do
      expect(component(user, style: "badge").render?).to be true
    end

    it "returns false when user is nil" do
      expect(component(nil).render?).to be false
    end

    it "returns true when style is nil (falls back to :inline)" do
      expect(component(user, style: nil).render?).to be true
    end

    it "returns true when style is invalid (falls back to :inline)" do
      expect(component(user, style: "invalid").render?).to be true
    end
  end
end
