# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Comment Instance Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  include_context "as member"

  def make_comment(overrides = {})
    create(:comment, **overrides)
  end

  # -------------------------------------------------------------------------
  # #hide! / #unhide!
  # -------------------------------------------------------------------------
  describe "#hide!" do
    it "sets is_hidden to true" do
      comment = make_comment
      expect { comment.hide! }.to change { comment.reload.is_hidden }.from(false).to(true)
    end
  end

  describe "#unhide!" do
    it "sets is_hidden to false" do
      comment = make_comment(is_hidden: true)
      expect { comment.unhide! }.to change { comment.reload.is_hidden }.from(true).to(false)
    end
  end

  # -------------------------------------------------------------------------
  # #update_last_commented_at_on_create (fired after_create)
  # -------------------------------------------------------------------------
  describe "#update_last_commented_at_on_create" do
    it "sets post last_commented_at to the comment's created_at" do
      post    = create(:post)
      comment = make_comment(post: post)
      expect(post.reload.last_commented_at.to_i).to eq(comment.created_at.to_i)
    end

    it "sets post last_comment_bumped_at when do_not_bump_post is false" do
      post    = create(:post)
      comment = make_comment(post: post, do_not_bump_post: false)
      expect(post.reload.last_comment_bumped_at.to_i).to eq(comment.created_at.to_i)
    end

    it "does not update last_comment_bumped_at when do_not_bump_post is true" do
      post = create(:post)
      post.update_columns(last_comment_bumped_at: nil)
      make_comment(post: post, do_not_bump_post: true)
      expect(post.reload.last_comment_bumped_at).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #update_last_commented_at_on_destroy (fired after_destroy)
  # -------------------------------------------------------------------------
  describe "#update_last_commented_at_on_destroy" do
    it "clears post last_commented_at when the only comment is deleted" do
      post    = create(:post)
      comment = make_comment(post: post)
      comment.destroy!
      expect(post.reload.last_commented_at).to be_nil
    end

    it "sets last_commented_at to the most recent remaining comment's created_at" do
      post     = create(:post)
      older    = make_comment(post: post)
      newer    = make_comment(post: post)
      older.update_columns(created_at: 2.hours.ago)
      newer.update_columns(created_at: 1.hour.ago)
      newer.destroy!
      expect(post.reload.last_commented_at.to_i).to eq(older.reload.created_at.to_i)
    end

    it "clears last_comment_bumped_at when no non-bump comments remain" do
      post    = create(:post)
      comment = make_comment(post: post, do_not_bump_post: true)
      post.update_columns(last_comment_bumped_at: nil)
      comment.destroy!
      expect(post.reload.last_comment_bumped_at).to be_nil
    end
  end
end
