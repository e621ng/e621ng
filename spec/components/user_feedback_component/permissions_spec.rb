# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackComponent, type: :component do
  let(:user) { create(:user) }

  def component(user = self.user)
    described_class.new(user: user, style: :badge)
  end

  describe "#show_add_feedback?" do
    context "as member" do
      include_context "as member"

      it "returns false because regular members are not moderators" do
        expect(component.send(:show_add_feedback?)).to be false
      end
    end

    context "as moderator" do
      include_context "as moderator"

      it "returns true when viewing another user with no active feedback" do
        expect(component.send(:show_add_feedback?)).to be true
      end

      it "returns false when viewing themselves" do
        expect(component(CurrentUser.user).send(:show_add_feedback?)).to be false
      end

      it "returns false when the user already has active feedback" do
        create(:user_feedback, user: user, category: "positive")
        expect(component.send(:show_add_feedback?)).to be false
      end
    end

    context "with no current user" do
      before do
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      after do
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      it "returns false" do
        expect(component.send(:show_add_feedback?)).to be false
      end
    end
  end
end
