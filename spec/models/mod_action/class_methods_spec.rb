# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ModAction Class Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .log
  # -------------------------------------------------------------------------
  describe ".log" do
    it "creates a new ModAction record" do
      expect { ModAction.log(:user_feedback_create, { user_id: 1 }) }
        .to change(ModAction, :count).by(1)
    end

    it "stores the action as a string" do
      ModAction.log(:user_feedback_create, { user_id: 1 })
      expect(ModAction.last.action).to eq("user_feedback_create")
    end

    it "stores the details in the values column" do
      ModAction.log(:user_feedback_create, { user_id: 42, reason: "noted", type: "positive", record_id: 7 })
      # log[:values] reads raw JSONB, bypassing the #values accessor's role-based filtering.
      expect(ModAction.last[:values]).to include("user_id" => 42, "reason" => "noted")
    end

    it "sets creator_id from CurrentUser" do
      ModAction.log(:user_feedback_create, {})
      expect(ModAction.last.creator_id).to eq(CurrentUser.id)
    end
  end

  # -------------------------------------------------------------------------
  # .available_action_keys
  # -------------------------------------------------------------------------
  describe ".available_action_keys" do
    it "returns all KnownActionKeys for a staff user" do
      staff = create(:moderator_user)
      expect(ModAction.available_action_keys(staff)).to eq(ModAction::KnownActionKeys)
    end

    it "excludes ProtectedActionKeys for a regular member" do
      member = create(:user)
      keys = ModAction.available_action_keys(member)
      ModAction::ProtectedActionKeys.each do |protected_key|
        expect(keys).not_to include(protected_key.to_sym)
      end
    end

    it "includes non-protected keys for a regular member" do
      member = create(:user)
      keys = ModAction.available_action_keys(member)
      expect(keys).to include(:user_feedback_create, :tag_alias_create, :blip_delete)
    end
  end
end
