# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Blip::ModAction Logging                             #
# --------------------------------------------------------------------------- #
#
# Blip fires three distinct callback-driven log actions:
#
#   after_update  → :blip_update    (when actor ≠ creator AND is_deleted did NOT change)
#   after_destroy → :blip_destroy   (always)
#   after_save    → :blip_delete    (when is_deleted changes to true  AND actor ≠ creator)
#                 → :blip_undelete  (when is_deleted changes to false AND actor ≠ creator)
#
# All tests create the blip as `creator`, then switch CurrentUser to `moderator`
# before triggering the action under test, ensuring actor ≠ creator for every
# branch that requires it.

RSpec.describe Blip do
  let(:creator)   { create(:user) }
  let(:moderator) { create(:moderator_user) }

  # Create the blip as the owning user, then hand control to the moderator.
  def make_blip(overrides = {})
    CurrentUser.scoped(creator, "127.0.0.1") { create(:blip, **overrides) }
  end

  before do
    CurrentUser.user    = moderator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # -------------------------------------------------------------------------
  # after_update → :blip_update
  # -------------------------------------------------------------------------
  describe "after_update — blip_update" do
    it "logs a blip_update action when a moderator edits the body" do
      blip = make_blip

      expect { blip.update!(body: "moderator changed this body") }
        .to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("blip_update")
      expect(log[:values]).to include(
        "blip_id" => blip.id,
        "user_id" => creator.id,
      )
    end

    it "does not log blip_update when the creator edits their own blip" do
      blip = make_blip
      CurrentUser.user = creator

      expect { blip.update!(body: "creator edited this body") }
        .not_to change(ModAction.where(action: "blip_update"), :count)
    end
  end

  # -------------------------------------------------------------------------
  # after_destroy → :blip_destroy
  # -------------------------------------------------------------------------
  describe "after_destroy — blip_destroy" do
    it "logs a blip_destroy action when a blip is destroyed" do
      blip    = make_blip
      blip_id = blip.id

      expect { blip.destroy! }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("blip_destroy")
      expect(log[:values]).to include(
        "blip_id" => blip_id,
        "user_id" => creator.id,
      )
    end
  end

  # -------------------------------------------------------------------------
  # after_save (is_deleted toggle) → :blip_delete / :blip_undelete
  # -------------------------------------------------------------------------
  describe "after_save — blip_delete / blip_undelete" do
    it "logs a blip_delete action when a moderator soft-deletes a blip" do
      blip = make_blip

      expect { blip.update!(is_deleted: true) }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("blip_delete")
      expect(log[:values]).to include(
        "blip_id" => blip.id,
        "user_id" => creator.id,
      )
    end

    it "logs a blip_undelete action when a moderator restores a blip" do
      blip = make_blip(is_deleted: true)
      action_count_before = ModAction.count

      blip.update!(is_deleted: false)

      expect(ModAction.count - action_count_before).to eq(1)
      log = ModAction.last
      expect(log.action).to eq("blip_undelete")
      expect(log[:values]).to include(
        "blip_id" => blip.id,
        "user_id" => creator.id,
      )
    end

    it "does not log blip_delete when the creator soft-deletes their own blip" do
      blip = make_blip
      CurrentUser.user = creator

      expect { blip.update!(is_deleted: true) }
        .not_to change(ModAction.where(action: "blip_delete"), :count)
    end
  end
end
