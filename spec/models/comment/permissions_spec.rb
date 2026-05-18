# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Comment::AccessMethods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  let(:creator)     { create(:user, show_hidden_comments: true) }
  let(:moderator)   { create(:moderator_user, show_hidden_comments: true) }
  let(:admin)       { create(:admin_user) }
  let(:other)       { create(:user) }
  let(:unverified)  { create(:unverified_user) }

  before do
    CurrentUser.user    = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
    Comment::SearchMethods.clear_comment_disabled_cache
  end

  def make_comment(overrides = {})
    create(:comment, **overrides)
  end

  # -------------------------------------------------------------------------
  # #can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "allows an admin to edit any comment" do
      comment = make_comment
      expect(comment.can_edit?(admin)).to be true
    end

    it "allows the creator to edit their own unwarned comment on a normal post" do
      comment = make_comment
      expect(comment.can_edit?(creator)).to be true
    end

    it "denies the creator from editing a warned comment" do
      comment = make_comment
      comment.user_warned!(:warning, moderator)
      expect(comment.can_edit?(creator)).to be false
    end

    it "denies the creator from editing on a locked post" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_locked: true)
      expect(comment.can_edit?(creator)).to be false
    end

    it "allows a moderator to edit on a locked post" do
      CurrentUser.user = moderator

      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_locked: true)
      expect(comment.can_edit?(moderator)).to be true
    end

    it "denies the creator from editing on a disabled post" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      expect(comment.can_edit?(creator)).to be false
    end

    it "denies a non-creator non-admin from editing" do
      comment = make_comment
      expect(comment.can_edit?(other)).to be false
    end

    it "denies an unverified user from editing" do
      comment = make_comment
      expect(comment.can_edit?(unverified)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_hide?
  # -------------------------------------------------------------------------
  describe "#can_hide?" do
    it "allows a moderator to hide any comment" do
      comment = make_comment
      expect(comment.can_hide?(moderator)).to be true
    end

    it "allows the creator to hide their own unwarned comment" do
      comment = make_comment
      expect(comment.can_hide?(creator)).to be true
    end

    it "denies the creator from hiding a warned comment" do
      comment = make_comment
      comment.user_warned!(:warning, moderator)
      expect(comment.can_hide?(creator)).to be false
    end

    it "denies the creator from hiding a comment on a disabled post" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      expect(comment.can_hide?(creator)).to be false
    end

    it "denies a non-creator non-moderator from hiding" do
      comment = make_comment
      expect(comment.can_hide?(other)).to be false
    end

    it "denies an unverified user from hiding" do
      comment = make_comment
      expect(comment.can_hide?(unverified)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_reply?
  # -------------------------------------------------------------------------
  describe "#can_reply?" do
    it "returns false for a sticky comment" do
      comment = make_comment(is_sticky: true)
      expect(comment.can_reply?(creator)).to be false
    end

    it "returns false for a member when the post has comments locked" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_locked: true)
      expect(comment.can_reply?(creator)).to be false
    end

    it "returns true for a moderator when the post has comments locked" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_locked: true)
      expect(comment.can_reply?(moderator)).to be true
    end

    it "returns false for a member when the post has comments disabled" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      expect(comment.can_reply?(creator)).to be false
    end

    it "returns true for a moderator when the post has comments disabled" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      expect(comment.can_reply?(moderator)).to be true
    end

    it "returns true for a normal comment" do
      comment = make_comment
      expect(comment.can_reply?(creator)).to be true
    end

    it "returns false for an unverified user" do
      comment = make_comment
      expect(comment.can_reply?(unverified)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_accessible?
  # -------------------------------------------------------------------------
  describe "#is_accessible?" do
    it "returns true for any user when the comment is not hidden" do
      comment = make_comment
      expect(comment.is_accessible?(other)).to be true
    end

    it "returns false for an anonymous user when the comment is hidden" do
      comment = make_comment(is_hidden: true)
      expect(comment.is_accessible?(User.anonymous)).to be false
    end

    it "returns false for an unrelated member when the comment is hidden" do
      comment = make_comment(is_hidden: true)
      expect(comment.is_accessible?(other)).to be false
    end

    it "returns true for the creator when the comment is hidden" do
      comment = make_comment(is_hidden: true)
      expect(comment.is_accessible?(creator)).to be true
    end

    it "returns true for a staff member when the comment is hidden" do
      comment = make_comment(is_hidden: true)
      expect(comment.is_accessible?(moderator)).to be true
    end

    it "returns false for a member when the post has comments disabled" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      Comment::SearchMethods.clear_comment_disabled_cache
      expect(comment.is_accessible?(other)).to be false
    end

    it "returns true for a staff member when the post has comments disabled" do
      post    = create(:post)
      comment = make_comment(post: post)
      post.update_columns(is_comment_disabled: true)
      Comment::SearchMethods.clear_comment_disabled_cache
      expect(comment.is_accessible?(moderator)).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #is_above_threshold? / #is_below_threshold?
  # -------------------------------------------------------------------------
  describe "#is_above_threshold?" do
    it "returns true for a sticky comment regardless of score" do
      comment = make_comment(is_sticky: true, score: -999)
      expect(comment.is_above_threshold?(other)).to be true
    end

    it "returns true when score meets the user threshold" do
      other.update_columns(comment_threshold: -10)
      comment = make_comment(score: -10)
      expect(comment.is_above_threshold?(other)).to be true
    end

    it "returns false when score is below the threshold and not sticky" do
      other.update_columns(comment_threshold: 0)
      comment = make_comment(is_sticky: false, score: -1)
      expect(comment.is_above_threshold?(other)).to be false
    end
  end

  describe "#is_below_threshold?" do
    it "returns false for a sticky comment" do
      comment = make_comment(is_sticky: true, score: -999)
      expect(comment.is_below_threshold?(other)).to be false
    end

    it "returns true when score is below threshold and not sticky" do
      other.update_columns(comment_threshold: 0)
      comment = make_comment(is_sticky: false, score: -1)
      expect(comment.is_below_threshold?(other)).to be true
    end

    it "returns false when score meets the threshold" do
      other.update_columns(comment_threshold: -10)
      comment = make_comment(score: -10)
      expect(comment.is_below_threshold?(other)).to be false
    end
  end
end
