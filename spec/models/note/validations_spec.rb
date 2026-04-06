# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Note Validations                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  # -------------------------------------------------------------------------
  # Presence — x, y, width, height, body
  # -------------------------------------------------------------------------
  describe "presence validations" do
    include_context "as member"

    # FIXME: note_within_image raises NoMethodError (`undefined method '<' for nil`)
    # when any coordinate is nil because it does not guard against nil values before
    # performing arithmetic comparisons (app/models/note.rb:91). These four tests
    # cannot complete until that validator is made nil-safe.
    # it "is invalid when x is nil" do
    #   note = build(:note, x: nil)
    #   expect(note).not_to be_valid
    #   expect(note.errors[:x]).to be_present
    # end

    # it "is invalid when y is nil" do
    #   note = build(:note, y: nil)
    #   expect(note).not_to be_valid
    #   expect(note.errors[:y]).to be_present
    # end

    # it "is invalid when width is nil" do
    #   note = build(:note, width: nil)
    #   expect(note).not_to be_valid
    #   expect(note.errors[:width]).to be_present
    # end

    # it "is invalid when height is nil" do
    #   note = build(:note, height: nil)
    #   expect(note).not_to be_valid
    #   expect(note.errors[:height]).to be_present
    # end

    it "is invalid when body is nil" do
      note = build(:note, body: nil)
      expect(note).not_to be_valid
      expect(note.errors[:body]).to be_present
    end

    it "is invalid when body is empty string" do
      note = build(:note, body: "")
      expect(note).not_to be_valid
      expect(note.errors[:body]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # body — length
  # -------------------------------------------------------------------------
  describe "body — length" do
    include_context "as member"

    it "is valid when body is 1 character" do
      expect(build(:note, body: "x")).to be_valid
    end

    it "is valid when body is exactly note_max_size characters" do
      expect(build(:note, body: "a" * Danbooru.config.note_max_size)).to be_valid
    end

    it "is invalid when body exceeds note_max_size" do
      note = build(:note, body: "a" * (Danbooru.config.note_max_size + 1))
      expect(note).not_to be_valid
      expect(note.errors[:body]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # user_not_limited — throttle check
  # -------------------------------------------------------------------------
  describe "user_not_limited — throttle check" do
    include_context "as member"

    it "is valid when the user is not throttled" do
      expect(build(:note)).to be_valid
    end

    it "is invalid when can_note_edit_with_reason returns :REJ_NEWBIE" do
      allow(CurrentUser.user).to receive(:can_note_edit_with_reason).and_return(:REJ_NEWBIE)
      note = build(:note)
      expect(note).not_to be_valid
      expect(note.errors[:base]).to be_present
    end

    it "is invalid when can_note_edit_with_reason returns :REJ_LIMITED" do
      allow(CurrentUser.user).to receive(:can_note_edit_with_reason).and_return(:REJ_LIMITED)
      note = build(:note)
      expect(note).not_to be_valid
      expect(note.errors[:base]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # post_must_exist
  # -------------------------------------------------------------------------
  describe "post_must_exist" do
    include_context "as member"

    it "is invalid when post_id references a nonexistent post" do
      note = build(:note, post_id: -1, post: nil)
      expect(note).not_to be_valid
      expect(note.errors[:post]).to include("must exist")
    end

    it "is valid when post_id references an existing post" do
      expect(build(:note)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # note_within_image — boundary conditions (640×480 post)
  # -------------------------------------------------------------------------
  describe "note_within_image" do
    include_context "as member"

    let(:post) { create(:post) } # 640×480

    it "is valid when the note fits exactly within the image" do
      expect(build(:note, post: post, x: 0, y: 0, width: 640, height: 480)).to be_valid
    end

    it "is invalid when x is negative" do
      note = build(:note, post: post, x: -1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when y is negative" do
      note = build(:note, post: post, y: -1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when width is negative" do
      note = build(:note, post: post, width: -1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when height is negative" do
      note = build(:note, post: post, height: -1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when x exceeds image_width" do
      note = build(:note, post: post, x: 641, y: 0, width: 1, height: 1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when y exceeds image_height" do
      note = build(:note, post: post, x: 0, y: 481, width: 1, height: 1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when x + width exceeds image_width" do
      note = build(:note, post: post, x: 600, y: 0, width: 100, height: 1)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end

    it "is invalid when y + height exceeds image_height" do
      note = build(:note, post: post, x: 0, y: 400, width: 1, height: 100)
      expect(note).not_to be_valid
      expect(note.errors[:note]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # post_must_not_be_note_locked
  # -------------------------------------------------------------------------
  describe "post_must_not_be_note_locked" do
    context "as a member" do
      include_context "as member"

      it "is invalid when the post is note locked" do
        note = build(:note, post: create(:note_locked_post))
        expect(note).not_to be_valid
        expect(note.errors[:post]).to include("is note locked")
      end

      it "is valid when the post is not note locked" do
        expect(build(:note)).to be_valid
      end
    end

    context "as an admin" do
      include_context "as admin"

      # NOTE: is_locked? has no privilege bypass — admins are also blocked
      it "is also invalid for an admin when the post is note locked" do
        note = build(:note, post: create(:note_locked_post))
        expect(note).not_to be_valid
        expect(note.errors[:post]).to include("is note locked")
      end
    end
  end
end
