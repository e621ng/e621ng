# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "NoteMethods" do
    describe "#can_have_notes?" do
      it "returns true for jpg posts" do
        expect(create(:post, file_ext: "jpg").can_have_notes?).to be true
      end

      it "returns true for png posts" do
        expect(create(:post, file_ext: "png").can_have_notes?).to be true
      end

      it "returns true for gif posts" do
        expect(create(:post, file_ext: "gif").can_have_notes?).to be true
      end

      it "returns true for webp posts" do
        expect(create(:post, file_ext: "webp").can_have_notes?).to be true
      end

      it "returns false for webm posts" do
        expect(create(:post, file_ext: "webm").can_have_notes?).to be false
      end

      it "returns false for swf posts" do
        expect(create(:post, file_ext: "swf").can_have_notes?).to be false
      end
    end

    describe "#has_notes?" do
      it "returns true when last_noted_at is present" do
        post = create(:post)
        post.update_columns(last_noted_at: Time.current)
        expect(post.has_notes?).to be true
      end

      it "returns false when last_noted_at is nil" do
        post = create(:post)
        expect(post.has_notes?).to be false
      end
    end

    describe "#copy_notes_to" do
      it "returns false and adds an error when source and destination are the same post" do
        post = create(:post)
        post.update_columns(last_noted_at: Time.current)
        create(:note, post: post)
        result = post.copy_notes_to(post)
        expect(result).to be false
        expect(post.errors[:base]).to be_present
      end

      it "returns false and adds an error when the source post has no notes" do
        source = create(:post)
        dest = create(:post)
        result = source.copy_notes_to(dest)
        expect(result).to be false
        expect(source.errors[:post]).to be_present
      end

      it "copies a single note and creates an inactive summary note on the destination" do
        source = create(:post)
        source.update_columns(last_noted_at: Time.current)
        create(:note, post: source, body: "Original note")
        dest = create(:post)

        expect { source.copy_notes_to(dest) }.to change { dest.notes.count }.by(2)

        summary = dest.notes.where(is_active: false).last
        expect(summary.body).to match(/Copied 1 note from post ##{source.id}/)
      end

      it "creates a plural summary note when copying multiple notes" do
        source = create(:post)
        source.update_columns(last_noted_at: Time.current)
        create(:note, post: source, body: "Note 1")
        create(:note, post: source, body: "Note 2")
        dest = create(:post)

        source.copy_notes_to(dest)

        summary = dest.notes.where(is_active: false).last
        expect(summary.body).to match(/Copied 2 notes from post ##{source.id}/)
      end

      it "syncs NOTE_COPY_TAGS from source to destination" do
        source = create(:post)
        source.update_columns(last_noted_at: Time.current)
        create(:note, post: source)

        # Give source a translation tag and make sure destination doesn't have it
        source.update!(tag_string: "#{source.tag_string} translated")
        dest = create(:post)

        source.copy_notes_to(dest, copy_tags: ["translated"])
        expect(dest.reload.tag_array).to include("translated")
      end
    end
  end
end
