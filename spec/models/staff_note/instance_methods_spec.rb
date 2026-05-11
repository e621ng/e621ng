# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       StaffNote Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe StaffNote do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #user_name
  # -------------------------------------------------------------------------
  describe "#user_name" do
    it "returns the name of the associated user" do
      user = create(:user)
      note = create(:staff_note, user: user)
      expect(note.user_name).to eq(user.name)
    end
  end

  # -------------------------------------------------------------------------
  # #user_name=
  # -------------------------------------------------------------------------
  describe "#user_name=" do
    it "sets user_id by looking up the user by name" do
      user = create(:user)
      note = build(:staff_note)
      note.user_name = user.name
      expect(note.user_id).to eq(user.id)
    end

    it "sets user_id to nil when the name does not exist" do
      note = build(:staff_note)
      note.user_name = "nonexistent_user_xyz"
      expect(note.user_id).to be_nil
    end
  end
end
