# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffNote Factory                                   #
# --------------------------------------------------------------------------- #

RSpec.describe StaffNote do
  include_context "as admin"

  describe "factory" do
    it "produces a valid staff_note with build" do
      note = build(:staff_note)
      expect(note).to be_valid, note.errors.full_messages.join(", ")
    end

    it "produces a valid staff_note with create" do
      note = create(:staff_note)
      expect(note).to be_persisted
    end
  end
end
