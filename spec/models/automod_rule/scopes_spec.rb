# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          AutomodRule Scopes                                 #
# --------------------------------------------------------------------------- #

RSpec.describe AutomodRule do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .enabled
  # -------------------------------------------------------------------------
  describe ".enabled" do
    let!(:enabled_rule)  { create(:automod_rule) }
    let!(:disabled_rule) { create(:disabled_automod_rule) }

    it "includes rules where enabled is true" do
      expect(AutomodRule.enabled).to include(enabled_rule)
    end

    it "excludes rules where enabled is false" do
      expect(AutomodRule.enabled).not_to include(disabled_rule)
    end
  end
end
