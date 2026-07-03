# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Comment Validations                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  # -------------------------------------------------------------------------
  # body — presence
  # -------------------------------------------------------------------------
  describe "body — presence" do
    include_context "as member"

    it "is invalid with an empty body" do
      comment = build(:comment, body: "")
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # body — length
  # -------------------------------------------------------------------------
  describe "body — length" do
    include_context "as member"

    it "is invalid when body is 0 characters" do
      comment = build(:comment, body: "")
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to be_present
    end

    it "is valid when body is 1 character" do
      comment = build(:comment, body: "x")
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end

    it "is invalid when body exceeds comment_max_size" do
      comment = build(:comment, body: "a" * (Danbooru.config.comment_max_size + 1))
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to be_present
    end

    it "is valid when body is exactly comment_max_size characters" do
      comment = build(:comment, body: "a" * Danbooru.config.comment_max_size)
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_post_exists — on: :create only
  # -------------------------------------------------------------------------
  describe "post existence — validate_post_exists" do
    include_context "as member"

    it "is invalid on create when post_id references a nonexistent post" do
      comment = build(:comment, post_id: -1)
      expect(comment).not_to be_valid
      expect(comment.errors[:post]).to include("must exist")
    end

    it "is valid on create when post_id references an existing post" do
      post    = create(:post)
      comment = build(:comment, post: post)
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end

    it "does not re-validate post existence on update" do
      comment = create(:comment)
      comment.post.destroy!
      comment.body = "updated body content"
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # post_not_comment_locked — on: :create only
  # -------------------------------------------------------------------------
  describe "comment locked post — post_not_comment_locked" do
    let(:locked_post) { create(:post).tap { |p| p.update_columns(is_comment_locked: true) } }

    context "as a member" do
      include_context "as member"

      it "is invalid when the post has comments locked" do
        comment = build(:comment, post: locked_post)
        expect(comment).not_to be_valid
        expect(comment.errors[:base]).to include("Post has comments locked")
      end

      it "does not re-validate comment lock on update" do
        post    = create(:post)
        comment = create(:comment, post: post)
        post.update_columns(is_comment_locked: true)
        comment.body = "updated body after lock"
        expect(comment).to be_valid, comment.errors.full_messages.join(", ")
      end
    end

    context "as a moderator" do
      include_context "as moderator"

      it "is valid when the post has comments locked" do
        comment = build(:comment, post: locked_post)
        expect(comment).to be_valid, comment.errors.full_messages.join(", ")
      end
    end
  end

  # -------------------------------------------------------------------------
  # post_not_comment_disabled — on: :create only
  # -------------------------------------------------------------------------
  describe "comment disabled post — post_not_comment_locked" do
    let(:disabled_post) { create(:post).tap { |p| p.update_columns(is_comment_disabled: true) } }

    context "as a member" do
      include_context "as member"

      it "is invalid when the post has comments disabled" do
        comment = build(:comment, post: disabled_post)
        expect(comment).not_to be_valid
        expect(comment.errors[:base]).to include("Post has comments disabled")
      end
    end

    context "as a moderator" do
      include_context "as moderator"

      it "is valid when the post has comments disabled" do
        comment = build(:comment, post: disabled_post)
        expect(comment).to be_valid, comment.errors.full_messages.join(", ")
      end
    end
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited — happy path
  # -------------------------------------------------------------------------
  describe "creator throttle — validate_creator_is_not_limited" do
    include_context "as member"

    it "is valid when the creator is not throttled" do
      comment = build(:comment)
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end
  end
end
