# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Note Instance Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as admin"

  def make_note(overrides = {})
    create(:note, **overrides)
  end

  # -------------------------------------------------------------------------
  # #rescale!
  # -------------------------------------------------------------------------
  describe "#rescale!" do
    it "multiplies x, y, width, and height by the given scale factors" do
      note = make_note(x: 10, y: 10, width: 100, height: 50)
      note.rescale!(2.0, 3.0)
      note.reload
      expect(note.x).to eq(20)
      expect(note.y).to eq(30)
      expect(note.width).to eq(200)
      expect(note.height).to eq(150)
    end

    it "persists the changes to the database" do
      note = make_note(x: 10, y: 10, width: 100, height: 50)
      note.rescale!(2.0, 3.0)
      expect(note.reload.x).to eq(20)
    end
  end

  # -------------------------------------------------------------------------
  # #update_post — after_save side effect
  # -------------------------------------------------------------------------
  describe "#update_post" do
    it "sets post.last_noted_at when an active note is saved" do
      post = create(:post)
      note = make_note(post: post)
      expect(post.reload.last_noted_at).to be_within(2.seconds).of(note.updated_at)
    end

    it "sets post.last_noted_at to nil when all notes on the post are inactive" do
      post = create(:post)
      note = make_note(post: post)
      note.update!(is_active: false)
      expect(post.reload.last_noted_at).to be_nil
    end

    it "keeps last_noted_at set when one of two notes is inactivated but the other remains active" do
      post   = create(:post)
      note_a = make_note(post: post)
      _note_b = make_note(post: post)
      note_a.update!(is_active: false)
      expect(post.reload.last_noted_at).not_to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #revert_to
  # -------------------------------------------------------------------------
  describe "#revert_to" do
    it "loads attributes from the target version without saving" do
      note = make_note(body: "version one", x: 10)
      v1   = note.versions.last
      note.update!(body: "version two", x: 20)

      note.revert_to(v1)

      expect(note.body).to eq("version one")
      expect(note.x).to eq(10)
      expect(note).to be_changed
    end

    it "raises Note::RevertError when the version belongs to a different note" do
      note_a = make_note
      note_b = make_note
      version_b = note_b.versions.last

      expect { note_a.revert_to(version_b) }.to raise_error(Note::RevertError)
    end
  end

  # -------------------------------------------------------------------------
  # #revert_to!
  # -------------------------------------------------------------------------
  describe "#revert_to!" do
    it "loads attributes from the target version and saves" do
      note = make_note(body: "original body")
      v1   = note.versions.last
      note.update!(body: "mutated body")

      note.revert_to!(v1)
      note.reload

      expect(note.body).to eq("original body")
    end

    it "raises Note::RevertError when the version belongs to a different note" do
      note_a = make_note
      note_b = make_note
      version_b = note_b.versions.last

      expect { note_a.revert_to!(version_b) }.to raise_error(Note::RevertError)
    end
  end

  # -------------------------------------------------------------------------
  # #copy_to
  # -------------------------------------------------------------------------
  describe "#copy_to" do
    it "creates a new note on the target post" do
      source_post = create(:post)   # 640×480
      note        = make_note(post: source_post, x: 10, y: 10, width: 100, height: 50)
      target_post = create(:post)   # also 640×480

      note.copy_to(target_post)

      new_note = Note.where(post_id: target_post.id).last
      expect(new_note).to be_present
    end

    it "preserves coordinates when source and target have the same dimensions" do
      source_post = create(:post)   # 640×480
      note        = make_note(post: source_post, x: 64, y: 48, width: 64, height: 48)
      target_post = create(:post)   # 640×480 — ratio 1:1

      note.copy_to(target_post)

      new_note = Note.where(post_id: target_post.id).last
      expect(new_note.x).to eq(64)
      expect(new_note.y).to eq(48)
      expect(new_note.width).to eq(64)
      expect(new_note.height).to eq(48)
    end

    it "scales coordinates proportionally when the target has different dimensions" do
      source_post = create(:post)   # 640×480
      note        = make_note(post: source_post, x: 320, y: 240, width: 64, height: 48)
      target_post = create(:post)
      target_post.update_columns(image_width: 1280, image_height: 960)

      note.copy_to(target_post)

      new_note = Note.where(post_id: target_post.id).last
      # width_ratio = 1280/640 = 2.0, height_ratio = 960/480 = 2.0
      expect(new_note.x).to eq(640)
      expect(new_note.y).to eq(480)
      expect(new_note.width).to eq(128)
      expect(new_note.height).to eq(96)
    end

    it "creates the new note with version 1 (create_version callback fires on save)" do
      source_post = create(:post)
      note        = make_note(post: source_post)
      target_post = create(:post)

      note.copy_to(target_post)

      new_note = Note.where(post_id: target_post.id).last
      expect(new_note.version).to eq(1)
    end

    it "does not change the original note's post_id" do
      source_post = create(:post)
      note        = make_note(post: source_post)
      target_post = create(:post)

      note.copy_to(target_post)

      expect(note.reload.post_id).to eq(source_post.id)
    end
  end

  # -------------------------------------------------------------------------
  # .undo_changes_by_user
  # -------------------------------------------------------------------------
  describe ".undo_changes_by_user" do
    let(:creator)    { create(:user) }
    let(:vandal)     { create(:user) }

    it "deletes all NoteVersion records by the vandal" do
      note = CurrentUser.scoped(creator, "127.0.0.1") { make_note(body: "original") }
      CurrentUser.scoped(vandal, "127.0.0.1") { note.update!(body: "vandalized") }

      Note.undo_changes_by_user(vandal.id)

      expect(NoteVersion.where(updater_id: vandal.id).count).to eq(0)
    end

    it "reverts the note body to the most recent pre-vandal version" do
      note = CurrentUser.scoped(creator, "127.0.0.1") { make_note(body: "original") }
      CurrentUser.scoped(vandal, "127.0.0.1") { note.update!(body: "vandalized") }

      Note.undo_changes_by_user(vandal.id)

      expect(note.reload.body).to eq("original")
    end

    it "leaves the note unchanged when the vandal was the sole editor (no prior versions remain)" do
      # When the vandal is the only editor, delete_all removes all NoteVersions.
      # note.versions.last returns nil, so the if-branch is skipped and the note
      # body stays at the vandal's value. This is a known edge case.
      note = CurrentUser.scoped(vandal, "127.0.0.1") { make_note(body: "vandal only") }

      Note.undo_changes_by_user(vandal.id)

      expect(NoteVersion.where(note_id: note.id).count).to eq(0)
      expect(note.reload.body).to eq("vandal only")
    end
  end
end
