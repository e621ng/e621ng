# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffNote Scopes                                    #
# --------------------------------------------------------------------------- #

RSpec.describe StaffNote do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    let!(:active_note)  { create(:staff_note, is_deleted: false) }
    let!(:deleted_note) { create(:staff_note, is_deleted: true) }

    it "includes records where is_deleted is false" do
      expect(StaffNote.active).to include(active_note)
    end

    it "excludes records where is_deleted is true" do
      expect(StaffNote.active).not_to include(deleted_note)
    end
  end

  # -------------------------------------------------------------------------
  # .default_order
  # -------------------------------------------------------------------------
  describe ".default_order" do
    it "returns newer records before older ones" do
      older = create(:staff_note)
      newer = create(:staff_note)
      older.update_columns(created_at: 1.hour.ago)

      ids = StaffNote.default_order.ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
