# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         AutomodRule Factory                                 #
# --------------------------------------------------------------------------- #

RSpec.describe AutomodRule do
  include_context "as admin"

  describe "factory" do
    it "produces a valid record with build" do
      rule = build(:automod_rule)
      expect(rule).to be_valid, rule.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      rule = create(:automod_rule)
      expect(rule).to be_persisted
    end

    it "produces a disabled record with :disabled_automod_rule" do
      rule = create(:disabled_automod_rule)
      expect(rule).to be_persisted
      expect(rule.enabled).to be false
    end
  end
end
