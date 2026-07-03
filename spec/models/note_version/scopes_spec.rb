# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          NoteVersion Scopes                                 #
# --------------------------------------------------------------------------- #

RSpec.describe NoteVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    let(:target_user) { create(:user) }
    let(:other_user)  { create(:user) }

    let!(:version_by_target) do
      note = CurrentUser.scoped(target_user, "127.0.0.1") { create(:note) }
      note.versions.last
    end

    let!(:version_by_other) do
      note = CurrentUser.scoped(other_user, "127.0.0.1") { create(:note) }
      note.versions.last
    end

    it "returns versions whose updater_id matches the given user" do
      expect(NoteVersion.for_user(target_user.id)).to include(version_by_target)
    end

    it "excludes versions from other users" do
      expect(NoteVersion.for_user(target_user.id)).not_to include(version_by_other)
    end

    it "returns an empty relation when no versions exist for that user" do
      unknown_id = User.maximum(:id).to_i + 1
      expect(NoteVersion.for_user(unknown_id)).to be_empty
    end
  end
end
