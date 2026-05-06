# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackComponent, type: :component do
  let(:user) { create(:user) }

  def component(user = self.user)
    described_class.new(user: user, style: :badge)
  end

  describe "#positive" do
    context "as member" do
      include_context "as member"

      it "returns the number of positive feedback records" do
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "positive")
        expect(component.send(:positive)).to eq(2)
      end

      it "returns 0 when no positive feedback exists" do
        expect(component.send(:positive)).to eq(0)
      end
    end
  end

  describe "#neutral" do
    context "as member" do
      include_context "as member"

      it "returns the number of neutral feedback records" do
        create(:user_feedback, user: user, category: "neutral")
        expect(component.send(:neutral)).to eq(1)
      end

      it "returns 0 when no neutral feedback exists" do
        expect(component.send(:neutral)).to eq(0)
      end
    end
  end

  describe "#negative" do
    context "as member" do
      include_context "as member"

      it "returns the number of negative feedback records" do
        create(:user_feedback, user: user, category: "negative")
        create(:user_feedback, user: user, category: "negative")
        create(:user_feedback, user: user, category: "negative")
        expect(component.send(:negative)).to eq(3)
      end

      it "returns 0 when no negative feedback exists" do
        expect(component.send(:negative)).to eq(0)
      end
    end
  end

  describe "#deleted" do
    context "as admin" do
      include_context "as admin"

      it "returns the deleted feedback count for staff" do
        create(:deleted_user_feedback, user: user)
        create(:deleted_user_feedback, user: user)
        expect(component.send(:deleted)).to eq(2)
      end

      it "returns 0 when no deleted feedback exists" do
        expect(component.send(:deleted)).to eq(0)
      end
    end

    context "as member" do
      include_context "as member"

      it "returns 0 even when deleted feedback exists" do
        create(:deleted_user_feedback, user: user)
        expect(component.send(:deleted)).to eq(0)
      end
    end
  end

  describe "#active" do
    context "as member" do
      include_context "as member"

      it "returns the sum of positive, neutral, and negative feedback" do
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "neutral")
        create(:user_feedback, user: user, category: "negative")
        expect(component.send(:active)).to eq(4)
      end

      it "returns 0 when no active feedback exists" do
        expect(component.send(:active)).to eq(0)
      end

      it "excludes deleted feedback from the count" do
        create(:user_feedback, user: user, category: "positive")
        create(:deleted_user_feedback, user: user)
        expect(component.send(:active)).to eq(1)
      end
    end
  end

  describe "#total" do
    context "as admin" do
      include_context "as admin"

      it "includes deleted feedback for staff" do
        create(:user_feedback, user: user, category: "positive")
        create(:deleted_user_feedback, user: user)
        expect(component.send(:total)).to eq(2)
      end
    end

    context "as member" do
      include_context "as member"

      it "excludes deleted feedback for non-staff" do
        create(:user_feedback, user: user, category: "positive")
        create(:deleted_user_feedback, user: user)
        expect(component.send(:total)).to eq(1)
      end

      it "returns 0 when no feedback exists" do
        expect(component.send(:total)).to eq(0)
      end
    end
  end
end
