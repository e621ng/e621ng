# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumSubscription do
  include_context "as admin"

  describe "factory" do
    it "builds a valid record" do
      expect(build(:forum_subscription)).to be_valid
    end

    it "creates a valid record" do
      expect { create(:forum_subscription) }.not_to raise_error
    end
  end
end
