# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    User upload karma / upload slots                         #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  include_context "as admin"

  let(:user) { create(:user) }

  def set_karma(target, value)
    target.user_status.update_columns(upload_karma: value)
    target.reload
  end

  describe "#upload_slots" do
    before do
      allow(Danbooru.config.custom_configuration).to receive(:upload_slots_base).and_return(10)
    end

    it "equals the base for a fresh user with no activity" do
      expect(user.upload_slots).to eq(10)
    end

    it "is 0 when the user has no_uploading set, regardless of the formula" do
      user.update(no_uploading: true)
      expect(user.upload_slots).to eq(0)
    end

    it "subtracts pending posts and a quarter of the deleted group" do
      create(:pending_post, uploader: user)
      user.user_status.update_columns(post_replacement_rejected_count: 8)
      user.reload
      # 10 - 1 pending - (8 / 4) = 7
      expect(user.upload_slots).to eq(7)
    end

    it "never goes negative" do
      user.user_status.update_columns(post_replacement_rejected_count: 100)
      user.reload
      expect(user.upload_slots).to eq(0)
    end
  end

  describe "#can_upload_with_reason" do
    before do
      allow(Danbooru.config.custom_configuration).to receive_messages(
        upload_karma_l1_threshold: 100,
        upload_karma_l10_threshold: 10_000,
        upload_karma_free_threshold: 1,
        upload_slots_base: 10,
      )
    end

    it "allows an above-threshold user to bypass the queue" do
      member = create(:user)

      # zero out the user's upload slots so that the only reason they can upload is their karma level
      member.user_status.update_columns(post_replacement_rejected_count: 100)

      set_karma(member, user.required_karma_for_level(Danbooru.config.upload_karma_free_threshold))
      expect(member.can_upload_with_reason).to be true
    end

    it "allows an approver to bypass the queue" do
      approver = create(:approver_user)
      expect(approver.can_upload_with_reason).to be true
    end

    it "returns :REJ_UPLOAD_LIMIT when a below-threshold user is out of slots" do
      member = create(:user)
      member.user_status.update_columns(post_replacement_rejected_count: 100)
      member.reload
      expect(member.can_upload_with_reason).to eq(:REJ_UPLOAD_LIMIT)
    end
  end
end
