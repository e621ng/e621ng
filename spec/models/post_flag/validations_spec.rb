# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  # Helper: temporarily switch CurrentUser to a different user for the duration of a block.
  def as_user(user)
    old = CurrentUser.user
    CurrentUser.user = user
    yield
  ensure
    CurrentUser.user = old
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited (on: :create)
  # -------------------------------------------------------------------------
  describe "validate_creator_is_not_limited" do
    let(:post) { create(:post) }

    it "is invalid when creator has no_flagging set" do
      member = create(:user)
      member.no_flagging = true
      flag = build(:post_flag, post: post, creator: member)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is invalid when creator has exceeded the hourly flag limit" do
      member = create(:user)
      flag = build(:post_flag, post: post, creator: member)
      allow(member).to receive(:can_post_flag_with_reason).and_return(:REJ_LIMITED)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is invalid when creator is too new (REJ_NEWBIE)" do
      member = create(:user)
      flag = build(:post_flag, post: post, creator: member)
      allow(member).to receive(:can_post_flag_with_reason).and_return(:REJ_NEWBIE)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is valid when creator is a janitor regardless of throttle status" do
      janitor = create(:janitor_user)
      flag = build(:post_flag, post: post, creator: janitor)
      expect(flag).to be_valid(:create), flag.errors.full_messages.join(", ")
    end

    it "is invalid when the same post was already flagged within COOLDOWN_PERIOD" do
      member = create(:user)
      # Create the first flag as the member
      as_user(member) do
        PostFlag.create!(
          post: post,
          reason_name: "extreme",
          creator_ip_addr: "127.0.0.1",
        )
      end
      # Second flag by the same member on the same post within cooldown
      second = build(:post_flag, post: post, creator: member)
      allow(member).to receive(:can_post_flag_with_reason).and_return(true)
      expect(second).not_to be_valid(:create)
      expect(second.errors[:post]).to be_present
    end

    it "skips throttle and cooldown checks for deletion flags" do
      member = create(:user)
      member.no_flagging = true
      flag = build(:deletion_post_flag, post: post, creator: member)
      flag.valid?(:create)
      expect(flag.errors[:creator]).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # validate_post
  # -------------------------------------------------------------------------
  describe "validate_post" do
    it "is invalid when the post is deleted" do
      post = create(:deleted_post)
      flag = build(:post_flag, post: post)
      expect(flag).not_to be_valid
      expect(flag.errors[:post]).to include("is deleted")
    end

    it "is invalid when the post is status-locked and creator is a regular member" do
      member = create(:user)
      post = create(:status_locked_post)
      flag = build(:post_flag, post: post, creator: member)
      expect(flag).not_to be_valid
      expect(flag.errors[:post]).to include("is locked and cannot be flagged")
    end

    it "is valid when the post is status-locked and creator is an admin" do
      post = create(:status_locked_post)
      # CurrentUser is admin via include_context; belongs_to_creator will set creator to admin
      flag = build(:post_flag, post: post)
      flag.valid?
      expect(flag.errors[:post]).not_to include("is locked and cannot be flagged")
    end

    it "is valid when the post is status-locked but force_flag is true" do
      member = create(:user)
      post = create(:status_locked_post)
      flag = build(:post_flag, post: post, creator: member, force_flag: true)
      flag.valid?
      expect(flag.errors[:post]).not_to include("is locked and cannot be flagged")
    end
  end

  # -------------------------------------------------------------------------
  # validate_reason (on: :create)
  # -------------------------------------------------------------------------
  describe "validate_reason" do
    it "is invalid when reason_name is not a known reason" do
      flag = build(:post_flag, reason_name: "not_a_real_reason", reason: "something")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:reason]).to be_present
    end

    it "is invalid for 'inferior' when no parent_id is given" do
      flag = build(:post_flag, reason_name: "inferior", reason: "something")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("must exist")
    end

    it "is invalid for 'inferior' when parent_id equals the post's own id" do
      post = create(:post)
      flag = build(:post_flag, post: post, reason_name: "inferior", reason: "something")
      flag.parent_id = post.id
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("cannot be set to the post being flagged")
    end

    it "is invalid for 'inferior' when the parent post does not exist" do
      flag = build(:post_flag, reason_name: "inferior", reason: "something")
      flag.parent_id = 99_999_999
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("must exist")
    end

    it "is invalid for 'uploading_guidelines' when the post has the grandfathered_content tag" do
      post = create(:post, tag_string: "grandfathered_content")
      flag = build(:post_flag, post: post, reason_name: "uploading_guidelines", note: "reason")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:reason]).to be_present
    end

    it "is valid for each standard reason name that does not require explanation", skip: "This test is skipped on this fork" do
      %w[young_human dnp_artist pay_content previously_deleted real_porn].each do |reason_name|
        flag = build(:post_flag, reason_name: reason_name, reason: "something", note: nil)
        flag.valid?(:create)
        expect(flag.errors[:reason]).to be_empty,
                                        "expected reason '#{reason_name}' to be valid, got: #{flag.errors[:reason]}"
      end
    end
  end

  # -------------------------------------------------------------------------
  # validate_note_required_for_reason
  # -------------------------------------------------------------------------
  describe "validate_note_required_for_reason" do
    %w[uploading_guidelines traditional].each do |reason_name|
      context "with reason '#{reason_name}' (requires explanation)" do
        it "is invalid when note is blank" do
          flag = build(:post_flag, reason_name: reason_name, note: "")
          expect(flag).not_to be_valid
          expect(flag.errors[:note]).to include("is required for the selected reason")
        end

        it "is valid when note is present" do
          flag = build(:post_flag, reason_name: reason_name, note: "Here is an explanation.")
          flag.valid?
          expect(flag.errors[:note]).to be_empty
        end
      end
    end

    it "does not require a note for reasons without require_explanation" do
      flag = build(:post_flag, reason_name: "advertisement", note: nil, reason: "something")
      flag.valid?
      expect(flag.errors[:note]).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # validates :reason, presence: true
  # -------------------------------------------------------------------------
  describe "reason presence" do
    it "is invalid when reason is blank" do
      flag = build(:post_flag, reason: "", reason_name: nil)
      expect(flag).not_to be_valid
      expect(flag.errors[:reason]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # validates :note, length: { maximum: ... }
  # -------------------------------------------------------------------------
  describe "note length" do
    it "is invalid when note exceeds the maximum length" do
      flag = build(:post_flag, note: "a" * (Danbooru.config.comment_max_size + 1))
      expect(flag).not_to be_valid
      expect(flag.errors[:note]).to be_present
    end

    it "is valid at exactly the maximum length" do
      flag = build(:post_flag, note: "a" * Danbooru.config.comment_max_size)
      flag.valid?
      expect(flag.errors[:note]).to be_empty
    end
  end
end
