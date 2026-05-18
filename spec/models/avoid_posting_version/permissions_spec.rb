# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     AvoidPostingVersion Permissions                         #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPostingVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #hidden_attributes — staff_notes visibility
  #
  # NOTE: This model gates staff_notes on is_janitor?, while AvoidPosting gates
  # them on is_staff?. This means janitors can see staff_notes in version
  # history but not on the main record — likely an unintentional inconsistency.
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    let(:version) { create(:avoid_posting_version, staff_notes: "secret note") }

    it "includes :staff_notes for a regular member" do
      CurrentUser.user = create(:user)
      expect(version.hidden_attributes).to include(:staff_notes)
    end

    it "does not include :staff_notes for a janitor" do
      CurrentUser.user = create(:janitor_user)
      expect(version.hidden_attributes).not_to include(:staff_notes)
    end

    it "does not include :staff_notes for a moderator" do
      CurrentUser.user = create(:moderator_user)
      expect(version.hidden_attributes).not_to include(:staff_notes)
    end
  end
end
