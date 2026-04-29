# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ModAction Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #can_view?
  # -------------------------------------------------------------------------
  describe "#can_view?" do
    it "returns true for a staff user viewing a protected action" do
      record = ModAction.log(:staff_note_create, { id: 1, user_id: 1, body: "note" })
      staff  = create(:moderator_user)
      expect(record.can_view?(staff)).to be true
    end

    it "returns true for a staff user viewing a regular action" do
      record = ModAction.log(:user_feedback_create, { user_id: 1 })
      staff  = create(:janitor_user)
      expect(record.can_view?(staff)).to be true
    end

    it "returns false for a regular member viewing a protected action" do
      record = ModAction.log(:ip_ban_create, { ip_addr: "1.2.3.4", reason: "spam" })
      member = create(:user)
      expect(record.can_view?(member)).to be false
    end

    it "returns true for a regular member viewing a non-protected action" do
      record = ModAction.log(:user_feedback_create, { user_id: 1 })
      member = create(:user)
      expect(record.can_view?(member)).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #values
  # -------------------------------------------------------------------------
  # The #values accessor applies role-based filtering on top of the raw JSONB.
  # Tests for non-admin roles use CurrentUser.scoped to temporarily switch context
  # without interfering with the admin context set by include_context.
  describe "#values" do
    it "returns the full values hash for an admin" do
      record = ModAction.log(:user_feedback_create, { user_id: 1, reason: "test", type: "positive", record_id: 2 })
      expect(record.values).to include("user_id" => 1, "reason" => "test", "type" => "positive", "record_id" => 2)
    end

    it "strips unknown keys for a non-admin on a regular action" do
      record = ModAction.log(:user_feedback_create, { user_id: 1, reason: "test", type: "positive", record_id: 2, secret_field: "hidden" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { record.values }
      expect(result.keys).not_to include("secret_field")
    end

    it "returns an empty hash for a non-admin on ip_ban_create" do
      record = ModAction.log(:ip_ban_create, { ip_addr: "1.2.3.4", reason: "spam" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { record.values }
      expect(result).to eq({})
    end

    it "returns only hidden and note for a non-admin on upload_whitelist_create when not hidden" do
      record = ModAction.log(:upload_whitelist_create, { domain: "example.com", path: "/", note: "allowed", hidden: false })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { record.values }
      expect(result.keys).to contain_exactly("hidden", "note")
    end

    it "returns only hidden for a non-admin on upload_whitelist_create when hidden is true" do
      record = ModAction.log(:upload_whitelist_create, { domain: "example.com", path: "/", note: "secret", hidden: true })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { record.values }
      expect(result.keys).to contain_exactly("hidden")
    end

    it "returns only ticket_id for a non-moderator on ticket_update" do
      record = ModAction.log(:ticket_update, { ticket_id: 5, status: "approved", response: "done", status_was: "pending", response_was: "" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { record.values }
      expect(result).to eq("ticket_id" => 5)
    end

    it "returns full known-key values for a moderator on ticket_update" do
      record = ModAction.log(:ticket_update, { ticket_id: 5, status: "approved", response: "done", status_was: "pending", response_was: "" })
      moderator = create(:moderator_user)
      result = CurrentUser.scoped(moderator, "127.0.0.1") { record.values }
      expect(result.keys).to include("ticket_id", "status", "response")
    end

    it "returns an empty hash when values is not a Hash" do
      record = ModAction.log(:user_feedback_create, {})
      # Store an array in the JSONB column to trigger the non-Hash guard.
      record.update_columns(values: [1, 2, 3])
      expect(record.values).to eq({})
    end
  end

  # -------------------------------------------------------------------------
  # #hidden_attributes / #method_attributes
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    it "includes :values and :values_old" do
      record = create(:mod_action)
      expect(record.hidden_attributes).to include(:values, :values_old)
    end
  end

  describe "#method_attributes" do
    it "includes :values" do
      record = create(:mod_action)
      expect(record.method_attributes).to include(:values)
    end
  end
end
