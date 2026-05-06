# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       StaffNote Permissions                                 #
# --------------------------------------------------------------------------- #
#
# is_staff? delegates to is_janitor?, so janitor/moderator/admin all pass.
# A plain member does not.
#
# The note is created by `janitor` (the creator) in all tests below.

RSpec.describe StaffNote do
  let(:noted_user) { create(:user) }
  let(:janitor)    { create(:janitor_user) }
  let(:other_staff) { create(:janitor_user) }
  let(:admin)      { create(:admin_user) }
  let(:member)     { create(:user) }

  before do
    CurrentUser.user    = janitor
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_note(overrides = {})
    create(:staff_note, user: noted_user, **overrides)
  end

  # -------------------------------------------------------------------------
  # #can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "returns true for the janitor creator" do
      note = make_note
      expect(note.can_edit?(janitor)).to be true
    end

    it "returns true for an admin who is not the creator" do
      note = make_note
      expect(note.can_edit?(admin)).to be true
    end

    it "returns false for a staff member who is not the creator and not an admin" do
      note = make_note
      expect(note.can_edit?(other_staff)).to be false
    end

    it "returns false for a plain member" do
      note = make_note
      expect(note.can_edit?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_delete?
  # -------------------------------------------------------------------------
  describe "#can_delete?" do
    it "returns true for the janitor creator" do
      note = make_note
      expect(note.can_delete?(janitor)).to be true
    end

    it "returns true for an admin who is not the creator" do
      note = make_note
      expect(note.can_delete?(admin)).to be true
    end

    it "returns false for a staff member who is not the creator and not an admin" do
      note = make_note
      expect(note.can_delete?(other_staff)).to be false
    end

    it "returns false for a plain member" do
      note = make_note
      expect(note.can_delete?(member)).to be false
    end
  end
end
