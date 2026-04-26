# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ModAction Scopes                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  include_context "as admin"

  describe "scopes" do
    # -------------------------------------------------------------------------
    # .visible
    # -------------------------------------------------------------------------
    describe ".visible" do
      let!(:regular_action)   { ModAction.log(:user_feedback_create, { user_id: 1 }) }
      let!(:protected_action) { ModAction.log(:staff_note_create, { id: 1, user_id: 1, body: "note" }) }
      let!(:ip_ban_action)    { ModAction.log(:ip_ban_create, { ip_addr: "1.2.3.4", reason: "spam" }) }

      it "returns all records for a staff user (moderator)" do
        staff = create(:moderator_user)
        result = ModAction.visible(staff)
        expect(result).to include(regular_action, protected_action, ip_ban_action)
      end

      it "returns all records for a staff user (janitor)" do
        staff = create(:janitor_user)
        result = ModAction.visible(staff)
        expect(result).to include(regular_action, protected_action, ip_ban_action)
      end

      it "excludes protected actions for a regular member" do
        member = create(:user)
        result = ModAction.visible(member)
        expect(result).not_to include(protected_action, ip_ban_action)
      end

      it "includes non-protected actions for a regular member" do
        member = create(:user)
        result = ModAction.visible(member)
        expect(result).to include(regular_action)
      end
    end
  end
end
