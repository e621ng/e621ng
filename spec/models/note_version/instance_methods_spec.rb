# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     NoteVersion Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe NoteVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil when there is no prior version for the note" do
      note = create(:note)
      v1   = note.versions.last
      expect(v1.previous).to be_nil
    end

    it "returns the immediately preceding version after an update" do
      note = create(:note, body: "version one")
      v1   = note.versions.last

      note.update!(body: "version two")
      v2 = note.versions.last

      expect(v2.previous).to eq(v1)
    end

    it "returns the latest prior version, not an earlier one, when multiple versions exist" do
      note = create(:note, body: "v1")
      v1   = note.versions.last

      note.update!(body: "v2")
      v2 = note.versions.last

      note.update!(body: "v3")
      v3 = note.versions.last

      # v3.previous should be v2, not v1
      expect(v3.previous).to eq(v2)
      expect(v3.previous).not_to eq(v1)
    end

    it "does not return a version that belongs to a different note" do
      note_a = create(:note, body: "note a")
      note_b = create(:note, body: "note b")

      v_a = note_a.versions.last
      v_b = note_b.versions.last

      # Push v_b's updated_at to just before v_a's so timestamps overlap
      v_b.update_columns(updated_at: v_a.updated_at - 1.second)

      expect(v_a.previous).to be_nil
    end
  end
end
