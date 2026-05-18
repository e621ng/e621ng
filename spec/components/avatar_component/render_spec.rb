# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvatarComponent do
  include_context "as member"

  let(:user) { create(:user) }

  def component(user = self.user)
    described_class.new(user: user)
  end

  describe "#render?" do
    it "returns true for a user with no avatar" do
      expect(component.render?).to be true
    end

    it "returns true for a user with an avatar post" do
      post = create(:post)
      expect(component(create(:user, avatar_id: post.id)).render?).to be true
    end

    it "returns false when user is nil" do
      expect(component(nil).render?).to be false
    end
  end
end
