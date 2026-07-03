# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                             Note Scopes                                     #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as member"

  let!(:active_note)   { create(:note) }
  let!(:inactive_note) { create(:inactive_note) }

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    it "includes notes where is_active is true" do
      expect(Note.active).to include(active_note)
    end

    it "excludes notes where is_active is false" do
      expect(Note.active).not_to include(inactive_note)
    end
  end

  # -------------------------------------------------------------------------
  # .for_creator
  # -------------------------------------------------------------------------
  describe ".for_creator" do
    it "returns notes created by the given user id" do
      expect(Note.for_creator(active_note.creator_id)).to include(active_note)
    end

    it "excludes notes by other users" do
      other_user = create(:user)
      other_note = CurrentUser.scoped(other_user, "127.0.0.1") { create(:note) }
      expect(Note.for_creator(active_note.creator_id)).not_to include(other_note)
    end

    it "returns no results when user_id matches no notes" do
      expect(Note.for_creator(-1)).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # .post_tags_match
  # -------------------------------------------------------------------------
  describe ".post_tags_match" do
    it "returns notes on posts that match the given tag" do
      tag = active_note.post.tag_array.first
      expect(Note.post_tags_match(tag)).to include(active_note)
    end

    it "returns no results when no posts match the tag query" do
      expect(Note.post_tags_match("nonexistent_tag_xyz_#{SecureRandom.hex}")).to be_empty
    end
  end
end
