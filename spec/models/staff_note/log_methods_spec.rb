# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      StaffNote::ModAction Logging                           #
# --------------------------------------------------------------------------- #
#
# StaffNote fires two callback-driven log actions:
#
#   after_create → :staff_note_create  (always)
#   after_update → :staff_note_update  (when body changes)
#               → :staff_note_delete   (when is_deleted changes to true)
#               → :staff_note_undelete (when is_deleted changes to false)

RSpec.describe StaffNote do
  include_context "as admin"

  let(:noted_user) { create(:user) }

  def make_note(overrides = {})
    create(:staff_note, user: noted_user, **overrides)
  end

  # -------------------------------------------------------------------------
  # after_create → staff_note_create
  # -------------------------------------------------------------------------
  describe "after_create — staff_note_create" do
    it "logs a staff_note_create action when a note is created" do
      expect { make_note(body: "initial body") }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("staff_note_create")
      expect(log[:values]).to include(
        "user_id" => noted_user.id,
        "body"    => "initial body",
      )
    end

    it "includes the note id in the log values" do
      note = make_note
      expect(ModAction.last[:values]).to include("id" => note.id)
    end
  end

  # -------------------------------------------------------------------------
  # after_update → staff_note_update
  # -------------------------------------------------------------------------
  describe "after_update — staff_note_update" do
    it "logs a staff_note_update action when the body changes" do
      note = make_note(body: "old body")

      expect { note.update!(body: "new body") }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("staff_note_update")
      expect(log[:values]).to include(
        "id"       => note.id,
        "user_id"  => noted_user.id,
        "body"     => "new body",
        "old_body" => "old body",
      )
    end

    it "does not log staff_note_update when only non-body fields change" do
      note = make_note
      expect { note.update_columns(updated_at: 1.second.from_now) }
        .not_to change(ModAction.where(action: "staff_note_update"), :count)
    end
  end

  # -------------------------------------------------------------------------
  # after_update → staff_note_delete
  # -------------------------------------------------------------------------
  describe "after_update — staff_note_delete" do
    it "logs a staff_note_delete action when is_deleted changes to true" do
      note = make_note

      expect { note.update!(is_deleted: true) }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("staff_note_delete")
      expect(log[:values]).to include("id" => note.id, "user_id" => noted_user.id)
    end
  end

  # -------------------------------------------------------------------------
  # after_update → staff_note_undelete
  # -------------------------------------------------------------------------
  describe "after_update — staff_note_undelete" do
    it "logs a staff_note_undelete action when is_deleted changes to false" do
      note = make_note(is_deleted: true)
      count_before = ModAction.count

      note.update!(is_deleted: false)

      expect(ModAction.count - count_before).to eq(1)
      log = ModAction.last
      expect(log.action).to eq("staff_note_undelete")
      expect(log[:values]).to include("id" => note.id, "user_id" => noted_user.id)
    end
  end

  # -------------------------------------------------------------------------
  # both changes at once (body + is_deleted)
  # -------------------------------------------------------------------------
  describe "after_update — body change + soft-delete together" do
    it "logs both staff_note_update and staff_note_delete" do
      note = make_note(body: "original body")

      expect { note.update!(body: "updated body", is_deleted: true) }
        .to change(ModAction, :count).by(2)

      actions = ModAction.last(2).map(&:action)
      expect(actions).to include("staff_note_update", "staff_note_delete")
    end
  end
end
