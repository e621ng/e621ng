# frozen_string_literal: true

require "rails_helper"

RSpec.describe KarmaBadge do
  include_context "as member"

  let(:user) { create(:user) }

  def component(user = self.user)
    described_class.new(user: user)
  end

  def set_karma(target, value)
    target.user_status.update_columns(upload_karma: value)
    target.reload
  end

  describe "#render?" do
    it "returns false when user is nil" do
      expect(component(nil).render?).to be false
    end

    it "returns false for a user with no karma" do
      expect(component.render?).to be false
    end

    it "returns false for a user with negative karma" do
      set_karma(user, -7)
      expect(component.render?).to be false
    end

    it "returns true for a user with positive karma" do
      set_karma(user, 1)
      expect(component.render?).to be true
    end

    it "returns true for the user themselves with negative karma" do
      allow(CurrentUser).to receive(:user).and_return(user)
      set_karma(user, -7)
      expect(component.render?).to be true
    end

    it "returns true for staff with negative karma" do
      allow(CurrentUser).to receive(:user).and_return(create(:admin_user))
      set_karma(user, -7)
      expect(component.render?).to be true
    end
  end
end
