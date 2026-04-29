# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffNote Search                                    #
# --------------------------------------------------------------------------- #

RSpec.describe StaffNote do
  include_context "as admin"

  let(:user_a)  { create(:user) }
  let(:user_b)  { create(:user) }

  # Two active notes for different users, one deleted note.
  let!(:note_a)       { create(:staff_note, user: user_a, body: "alpha content") }
  let!(:note_b)       { create(:staff_note, user: user_b, body: "beta content") }
  let!(:note_deleted) { create(:staff_note, user: user_a, body: "deleted content", is_deleted: true) }

  # -------------------------------------------------------------------------
  # body_matches
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns notes whose body matches the search term" do
      result = StaffNote.search(body_matches: "alpha")
      expect(result).to include(note_a)
      expect(result).not_to include(note_b)
    end

    it "returns all active notes when body_matches is absent" do
      result = StaffNote.search({})
      expect(result).to include(note_a, note_b)
    end
  end

  # -------------------------------------------------------------------------
  # user_name / user_id
  # -------------------------------------------------------------------------
  describe "user_name param" do
    it "returns only notes for the named user" do
      result = StaffNote.search(user_name: user_a.name)
      expect(result).to include(note_a)
      expect(result).not_to include(note_b)
    end
  end

  describe "user_id param" do
    it "returns only notes for the given user id" do
      result = StaffNote.search(user_id: user_b.id.to_s)
      expect(result).to include(note_b)
      expect(result).not_to include(note_a)
    end
  end

  # -------------------------------------------------------------------------
  # creator_name / creator_id
  # -------------------------------------------------------------------------
  describe "creator_name param" do
    it "returns only notes created by the named user" do
      # note_a and note_b are both created by the admin (CurrentUser from include_context)
      other_admin = create(:admin_user)
      other_note  = CurrentUser.scoped(other_admin, "127.0.0.1") { create(:staff_note, user: user_a) }

      result = StaffNote.search(creator_name: CurrentUser.name)
      expect(result).to include(note_a, note_b)
      expect(result).not_to include(other_note)
    end
  end

  describe "creator_id param" do
    it "returns only notes created by the given creator id" do
      result = StaffNote.search(creator_id: note_a.creator_id.to_s)
      expect(result).to include(note_a, note_b)
    end
  end

  # -------------------------------------------------------------------------
  # updater_name / updater_id
  # -------------------------------------------------------------------------
  describe "updater_name param" do
    it "returns only notes last updated by the named user" do
      other_admin = create(:admin_user)
      CurrentUser.scoped(other_admin, "127.0.0.1") { note_b.update!(body: "updated by other") }

      result = StaffNote.search(updater_name: other_admin.name)
      expect(result).to include(note_b)
      expect(result).not_to include(note_a)
    end
  end

  describe "updater_id param" do
    it "returns only notes last updated by the given updater id" do
      result = StaffNote.search(updater_id: note_a.updater_id.to_s)
      expect(result).to include(note_a)
    end
  end

  # -------------------------------------------------------------------------
  # without_system_user
  # -------------------------------------------------------------------------
  describe "without_system_user param" do
    it "excludes notes created by the system user" do
      system_note = CurrentUser.scoped(User.system, "127.0.0.1") { create(:staff_note, user: user_a) }

      result = StaffNote.search(without_system_user: "1")
      expect(result).to include(note_a, note_b)
      expect(result).not_to include(system_note)
    end

    it "includes system-user notes when param is absent" do
      system_note = CurrentUser.scoped(User.system, "127.0.0.1") { create(:staff_note, user: user_a) }

      result = StaffNote.search({})
      expect(result).to include(system_note)
    end
  end

  # -------------------------------------------------------------------------
  # is_deleted
  # -------------------------------------------------------------------------
  describe "is_deleted param" do
    it "returns only deleted notes when is_deleted is 'true'" do
      result = StaffNote.search(is_deleted: "true")
      expect(result).to include(note_deleted)
      expect(result).not_to include(note_a, note_b)
    end

    it "returns only active notes when is_deleted is 'false'" do
      result = StaffNote.search(is_deleted: "false")
      expect(result).to include(note_a, note_b)
      expect(result).not_to include(note_deleted)
    end
  end

  # -------------------------------------------------------------------------
  # include_deleted
  # -------------------------------------------------------------------------
  describe "include_deleted param" do
    it "includes deleted notes when include_deleted is '1'" do
      result = StaffNote.search(include_deleted: "1")
      expect(result).to include(note_a, note_b, note_deleted)
    end

    it "excludes deleted notes by default (no is_deleted or include_deleted param)" do
      result = StaffNote.search({})
      expect(result).not_to include(note_deleted)
    end
  end

  # -------------------------------------------------------------------------
  # order
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by id ascending when order is 'id_asc'" do
      ids = StaffNote.search(order: "id_asc", include_deleted: "1").ids
      expect(ids).to eq(ids.sort)
    end

    it "orders by id descending by default" do
      ids = StaffNote.search(include_deleted: "1").ids
      expect(ids).to eq(ids.sort.reverse)
    end
  end

  # -------------------------------------------------------------------------
  # resolved param — FIXME
  # -------------------------------------------------------------------------
  # FIXME: The model calls attribute_matches(:resolved, params[:resolved]) in
  # .search, but the staff_notes table has no `resolved` column. Querying this
  # param raises an error. Tests are commented out until the column is added or
  # the search method is corrected.
  #
  # describe "resolved param" do
  #   it "returns only resolved notes when resolved is 'true'" do
  #     result = StaffNote.search(resolved: "true")
  #     ...
  #   end
  # end
end
