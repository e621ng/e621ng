# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostApproval Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe PostApproval do
  include_context "as member"

  # -------------------------------------------------------------------------
  # validate_approval
  # -------------------------------------------------------------------------
  describe "validate_approval" do
    describe "when the post is pending and not status-locked" do
      it "is valid" do
        record = build(:post_approval, post: create(:pending_post))
        expect(record).to be_valid, record.errors.full_messages.join(", ")
      end
    end

    describe "when the post is status-locked" do
      it "is invalid" do
        record = build(:post_approval, post: create(:pending_post, is_status_locked: true))
        expect(record).not_to be_valid
      end

      it "adds an error on :post" do
        record = build(:post_approval, post: create(:pending_post, is_status_locked: true))
        record.valid?
        expect(record.errors[:post]).to include("is locked and cannot be approved")
      end
    end

    describe "when the post is already active" do
      it "is invalid" do
        record = build(:post_approval, post: create(:post))
        expect(record).not_to be_valid
      end

      it "adds an error on :post" do
        record = build(:post_approval, post: create(:post))
        record.valid?
        expect(record.errors[:post]).to include("is already active and cannot be approved")
      end
    end

    describe "when the post is flagged" do
      it "is valid (flagged status is not active)" do
        record = build(:post_approval, post: create(:flagged_post))
        expect(record).to be_valid, record.errors.full_messages.join(", ")
      end
    end

    describe "when the post is deleted" do
      it "is valid (deleted status is not active)" do
        record = build(:post_approval, post: create(:deleted_post))
        expect(record).to be_valid, record.errors.full_messages.join(", ")
      end
    end
  end
end
