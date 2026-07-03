# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Note Versioning                                    #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as admin"

  def make_note(overrides = {})
    create(:note, **overrides)
  end

  # -------------------------------------------------------------------------
  # after_save :create_version — NoteVersion creation
  # -------------------------------------------------------------------------
  describe "after_save :create_version" do
    it "creates a NoteVersion when the note is first saved" do
      expect { make_note }.to change(NoteVersion, :count).by(1)
    end

    it "sets note.version to 1 after create" do
      note = make_note
      expect(note.version).to eq(1)
    end

    it "creates a NoteVersion when body changes" do
      note = make_note
      expect { note.update!(body: "updated body") }.to change(NoteVersion, :count).by(1)
    end

    it "creates a NoteVersion when x changes" do
      note = make_note
      expect { note.update!(x: note.x + 1) }.to change(NoteVersion, :count).by(1)
    end

    it "creates a NoteVersion when y changes" do
      note = make_note
      expect { note.update!(y: note.y + 1) }.to change(NoteVersion, :count).by(1)
    end

    it "creates a NoteVersion when width changes" do
      note = make_note
      expect { note.update!(width: note.width + 1) }.to change(NoteVersion, :count).by(1)
    end

    it "creates a NoteVersion when height changes" do
      note = make_note
      expect { note.update!(height: note.height + 1) }.to change(NoteVersion, :count).by(1)
    end

    it "creates a NoteVersion when is_active changes" do
      note = make_note
      expect { note.update!(is_active: false) }.to change(NoteVersion, :count).by(1)
    end

    it "does NOT create a NoteVersion when no versioned attribute changes" do
      note = make_note
      note.reload
      expect { note.save! }.not_to change(NoteVersion, :count)
    end

    it "increments note.version by 1 for each versioned change" do
      note = make_note                    # version == 1
      note.update!(body: "version two")   # version == 2
      note.update!(body: "version three") # version == 3
      expect(note.reload.version).to eq(3)
    end
  end

  # -------------------------------------------------------------------------
  # NoteVersion attributes
  # -------------------------------------------------------------------------
  describe "NoteVersion attributes" do
    it "records the updater_id from CurrentUser at save time" do
      note = make_note
      expect(note.versions.last.updater_id).to eq(CurrentUser.id)
    end

    it "records a snapshot of the note's attributes" do
      note = make_note(x: 10, y: 20, width: 100, height: 50, body: "snapshot check")
      v    = note.versions.last

      expect(v.post_id).to eq(note.post_id)
      expect(v.x).to eq(10)
      expect(v.y).to eq(20)
      expect(v.width).to eq(100)
      expect(v.height).to eq(50)
      expect(v.body).to eq("snapshot check")
      expect(v.is_active).to be true
      expect(v.version).to eq(1)
    end

    it "records the updater from a different CurrentUser when scoped" do
      note         = make_note
      other_user   = create(:user)

      CurrentUser.scoped(other_user, "127.0.0.1") do
        note.update!(body: "updated by other")
      end

      expect(note.versions.last.updater_id).to eq(other_user.id)
    end
  end
end
