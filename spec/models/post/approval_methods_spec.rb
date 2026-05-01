# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ApprovalMethods" do
    describe "#is_approvable?" do
      it "returns true for a pending post with no approver and no status lock" do
        post = create(:pending_post)
        expect(post.is_approvable?).to be true
      end

      it "returns false when the post is not pending" do
        post = create(:post, is_pending: false)
        expect(post.is_approvable?).to be false
      end

      it "returns false when the post is status-locked" do
        post = create(:status_locked_post, is_pending: true)
        expect(post.is_approvable?).to be false
      end

      it "returns false when the post already has an approver" do
        approver = create(:user)
        post = create(:pending_post)
        post.update_columns(approver_id: approver.id)
        expect(post.reload.is_approvable?).to be false
      end
    end

    describe "#approve!" do
      it "clears the pending flag" do
        post = create(:pending_post)
        post.approve!
        expect(post.reload.is_pending).to be false
      end

      it "creates a PostApproval record when approver differs from uploader" do
        approver = create(:admin_user)
        post = create(:pending_post)
        expect { post.approve!(approver) }.to change(PostApproval, :count).by(1)
      end

      it "does not create a PostApproval record when the uploader approves their own post" do
        post = create(:pending_post)
        expect { post.approve!(post.uploader) }.not_to change(PostApproval, :count)
      end

      it "assigns the approver to the post" do
        approver = create(:admin_user)
        post = create(:pending_post)
        post.approve!(approver)
        expect(post.reload.approver).to eq(approver)
      end

      it "is a no-op when the post already has an approver set" do
        approver = create(:admin_user)
        other    = create(:admin_user)
        post = create(:pending_post)
        post.update_columns(approver_id: approver.id, is_pending: false)

        expect { post.reload.approve!(other) }.not_to change(PostApproval, :count)
      end
    end

    describe "#unapprove!" do
      it "marks the post as pending again" do
        post = create(:post, is_pending: false)
        post.unapprove!
        expect(post.reload.is_pending).to be true
      end

      it "clears the approver" do
        approver = create(:admin_user)
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        post.reload.unapprove!
        expect(post.reload.approver).to be_nil
      end
    end

    describe "#is_unapprovable?" do
      it "returns true when approver matches the current user and post is not pending or deleted" do
        approver = create(:admin_user)
        post = create(:post, is_pending: false)
        post.update_columns(approver_id: approver.id)
        expect(post.reload.is_unapprovable?(approver)).to be true
      end

      it "returns false when the post is pending" do
        post = create(:pending_post)
        expect(post.is_unapprovable?(post.uploader)).to be false
      end

      it "returns false when the post is deleted" do
        post = create(:deleted_post)
        expect(post.is_unapprovable?(post.uploader)).to be false
      end

      it "returns false when the approver differs from the requesting user" do
        approver = create(:admin_user)
        other    = create(:admin_user)
        post = create(:post, is_pending: false)
        post.update_columns(approver_id: approver.id)
        expect(post.reload.is_unapprovable?(other)).to be false
      end
    end

    describe "#approved_by?" do
      it "returns true when the approver attribute matches the user" do
        approver = create(:admin_user)
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        expect(post.reload.approved_by?(approver)).to be true
      end

      it "returns true when a PostApproval record exists for the user" do
        approver = create(:admin_user)
        post = create(:pending_post)
        PostApproval.create!(post: post, user: approver)
        expect(post.approved_by?(approver)).to be true
      end

      it "returns false when the user has not approved the post" do
        user = create(:user)
        post = create(:post)
        expect(post.approved_by?(user)).to be false
      end
    end

    describe "#unflag!" do
      it "sets is_flagged to false" do
        post = create(:flagged_post)
        post.unflag!
        expect(post.reload.is_flagged).to be false
      end

      it "resolves all open flags on the post" do
        post = create(:flagged_post)
        create(:post_flag_reason)
        flag = create(:post_flag, post: post)
        post.unflag!
        expect(flag.reload.is_resolved).to be true
      end
    end
  end
end
