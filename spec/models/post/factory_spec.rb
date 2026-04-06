# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "factory" do
    it "produces a valid post with build" do
      post = build(:post)
      expect(post).to be_valid, post.errors.full_messages.join(", ")
    end

    it "produces a persisted post with create" do
      expect(create(:post)).to be_persisted
    end

    it "sets the uploader association" do
      expect(create(:post).uploader).to be_a(User)
    end

    it "sets a unique md5 for each instance" do
      a = create(:post)
      b = create(:post)
      expect(a.md5).not_to eq(b.md5)
    end

    it "sets a default safe rating" do
      expect(create(:post).rating).to eq("s")
    end

    it "sets file attributes" do
      post = create(:post)
      expect(post.file_ext).to eq("jpg")
      expect(post.image_width).to eq(640)
      expect(post.image_height).to eq(480)
      expect(post.file_size).to eq(10_000)
    end

    it "sets tag_count after save" do
      post = create(:post)
      expect(post.tag_count).to be > 0
    end

    describe ":pending_post" do
      it "produces a persisted post" do
        expect(create(:pending_post)).to be_persisted
      end

      it "is pending" do
        expect(create(:pending_post).is_pending).to be true
      end
    end

    describe ":deleted_post" do
      it "produces a persisted post" do
        expect(create(:deleted_post)).to be_persisted
      end

      it "is deleted and not pending" do
        post = create(:deleted_post)
        expect(post.is_deleted).to be true
        expect(post.is_pending).to be false
      end
    end

    describe ":flagged_post" do
      it "is flagged" do
        expect(create(:flagged_post).is_flagged).to be true
      end
    end

    describe ":rating_locked_post" do
      it "has rating locked" do
        expect(create(:rating_locked_post).is_rating_locked).to be true
      end
    end

    describe ":note_locked_post" do
      it "has notes locked" do
        expect(create(:note_locked_post).is_note_locked).to be true
      end
    end

    describe ":status_locked_post" do
      it "has status locked" do
        expect(create(:status_locked_post).is_status_locked).to be true
      end
    end
  end
end
