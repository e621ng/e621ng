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
      create(:post_flag_reason)
      flag = build(:post_flag, post: post, creator: member)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is invalid when creator has exceeded the hourly flag limit" do
      member = create(:user)
      create(:post_flag_reason)
      flag = build(:post_flag, post: post, creator: member)
      allow(member).to receive(:can_post_flag_with_reason).and_return(:REJ_LIMITED)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is invalid when creator is too new (REJ_NEWBIE)" do
      member = create(:user)
      create(:post_flag_reason)
      flag = build(:post_flag, post: post, creator: member)
      allow(member).to receive(:can_post_flag_with_reason).and_return(:REJ_NEWBIE)
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:creator]).to be_present
    end

    it "is valid when creator is a janitor regardless of throttle status" do
      janitor = create(:janitor_user)
      create(:post_flag_reason)
      flag = build(:post_flag, post: post, creator: janitor)
      expect(flag).to be_valid(:create), flag.errors.full_messages.join(", ")
    end

    it "is invalid when the same post was already flagged within COOLDOWN_PERIOD" do
      member = create(:user)
      # Create the first flag as the member
      as_user(member) do
        create(:post_flag, post: post)
      end
      # Second flag by the same member on the same post within cooldown
      create(:post_flag_reason)
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
      create(:post_flag_reason)
      flag = build(:post_flag, post: post)
      expect(flag).not_to be_valid
      expect(flag.errors[:post]).to include("is deleted")
    end

    it "is invalid when the post is status-locked and creator is a regular member" do
      member = create(:user)
      post = create(:status_locked_post)
      create(:post_flag_reason)
      flag = build(:post_flag, post: post, creator: member)
      expect(flag).not_to be_valid
      expect(flag.errors[:post]).to include("is locked and cannot be flagged")
    end

    it "is valid when the post is status-locked and creator is an admin" do
      post = create(:status_locked_post)
      # CurrentUser is admin via include_context; belongs_to_creator will set creator to admin
      create(:post_flag_reason)
      flag = build(:post_flag, post: post)
      flag.valid?
      expect(flag.errors[:post]).not_to include("is locked and cannot be flagged")
    end

    it "is valid when the post is status-locked but force_flag is true" do
      member = create(:user)
      post = create(:status_locked_post)
      create(:post_flag_reason)
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
      create(:post_flag_reason)
      flag = build(:post_flag, reason_name: "not_a_real_reason", reason: "something")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:reason]).to be_present
    end

    it "is invalid for 'need_parent_id' when no parent_id is given" do
      create(:needs_parent_id_post_flag_reason)
      flag = build(:needs_parent_id_post_flag, reason: "something")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("must exist")
    end

    it "is invalid for 'needs_parent_id' when parent_id equals the post's own id" do
      post = create(:post)
      create(:needs_parent_id_post_flag_reason)
      flag = build(:needs_parent_id_post_flag, reason: "something", post: post)
      flag.parent_id = post.id
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("cannot be set to the post being flagged")
    end

    it "is invalid for 'needs_parent_id' when the parent post does not exist" do
      create(:needs_parent_id_post_flag_reason)
      flag = build(:needs_parent_id_post_flag, reason: "something")
      flag.parent_id = 99_999_999
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:parent_id]).to include("must exist")
    end

    it "is invalid for targe tag '-grandfathered_content' when the post has the grandfathered_content tag" do
      post = create(:post, tag_string: "grandfathered_content")
      create(:grandfathering_post_flag_reason)
      flag = build(:grandfathering_post_flag, post: post, note: "reason")
      expect(flag).not_to be_valid(:create)
      expect(flag.errors[:reason]).to be_present
    end

    it "is valid for each standard reason name that does not require explanation" do
      flag_reason = create(:post_flag_reason)
      reason_name = flag_reason.name
      flag = build(:post_flag, reason_name: reason_name, reason: "something", note: nil)
      flag.valid?(:create)
      expect(flag.errors[:reason]).to be_empty,
                                      "expected reason '#{reason_name}' to be valid, got: #{flag.errors[:reason]}"
    end
  end

  # -------------------------------------------------------------------------
  # validate_note_required_for_reason
  # -------------------------------------------------------------------------
  describe "validate_note_required_for_reason" do
    context "with reason requires explanation" do
      it "is invalid when note is blank" do
        flag_reason = create(:needs_explanation_post_flag_reason)
        expect(flag_reason.needs_explanation?).to be true
        flag = build(:post_flag, reason_name: flag_reason.name, note: "")
        expect(flag).not_to be_valid
        expect(flag.errors[:note]).to include("is required for the selected reason")
      end

      it "is valid when note is present" do
        flag_reason = create(:needs_explanation_post_flag_reason)
        expect(flag_reason.needs_explanation?).to be true
        flag = build(:post_flag, reason_name: flag_reason.name, note: "Here is an explanation.")
        flag.valid?
        expect(flag.errors[:note]).to be_empty
      end
    end

    it "does not require a note for reasons without require_explanation" do
      flag_reason = create(:post_flag_reason)
      expect(flag_reason.needs_explanation?).to be false
      flag = build(:post_flag, reason_name: flag_reason.name, note: nil, reason: "something")
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
      create(:post_flag_reason)
      flag = build(:post_flag, note: "a" * (Danbooru.config.comment_max_size + 1))
      expect(flag).not_to be_valid
      expect(flag.errors[:note]).to be_present
    end

    it "is valid at exactly the maximum length" do
      create(:post_flag_reason)
      flag = build(:post_flag, note: "a" * Danbooru.config.comment_max_size)
      flag.valid?
      expect(flag.errors[:note]).to be_empty
    end
  end
end
