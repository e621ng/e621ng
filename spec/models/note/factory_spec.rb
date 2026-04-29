# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Note Factory Sanity                               #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as member"

  describe "factory" do
    it "produces a valid note with build" do
      expect(build(:note)).to be_valid
    end

    it "produces a valid note with create" do
      expect(create(:note)).to be_persisted
    end

    it "produces a valid inactive note" do
      note = create(:inactive_note)
      expect(note).to be_persisted
      expect(note.is_active).to be false
    end
  end
end
