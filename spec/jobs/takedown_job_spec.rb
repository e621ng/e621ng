# frozen_string_literal: true

require "rails_helper"

RSpec.describe TakedownJob do
  include_context "as admin"

  let(:approver) { create(:admin_user) }

  def perform(takedown, reason = "copyright infringement")
    described_class.perform_now(takedown.id, approver.id, reason)
  end

  describe "#perform" do
    describe "approver assignment" do
      let(:takedown) { create(:takedown_with_post) }

      it "sets the approver on the takedown" do
        perform(takedown)
        expect(takedown.reload.approver_id).to eq(approver.id)
      end
    end

    describe "mod action logging" do
      let(:takedown) { create(:takedown_with_post) }

      it "logs a takedown_process ModAction" do
        expect { perform(takedown) }.to change(ModAction, :count).by(1)
        expect(ModAction.last.action).to eq("takedown_process")
        expect(ModAction.last[:values]).to include("takedown_id" => takedown.id)
      end

      it "attributes the ModAction to the approver" do
        perform(takedown)
        expect(ModAction.last.creator_id).to eq(approver.id)
      end
    end

    describe "status update" do
      it "sets status to approved when all posts are marked for deletion" do
        post = create(:post)
        takedown = create(:takedown_with_post, post: post)
        takedown.update_columns(del_post_ids: post.id.to_s)
        perform(takedown)
        expect(takedown.reload.status).to eq("approved")
      end

      it "sets status to denied when no posts are marked for deletion" do
        takedown = create(:takedown_with_post)
        perform(takedown)
        expect(takedown.reload.status).to eq("denied")
      end

      it "sets status to partial when some posts are deleted and some are kept" do
        post1 = create(:post)
        post2 = create(:post)
        takedown = create(:takedown_with_post, post: post1)
        takedown.update_columns(
          post_ids: "#{post1.id} #{post2.id}",
          del_post_ids: post1.id.to_s,
        )
        perform(takedown)
        expect(takedown.reload.status).to eq("partial")
      end
    end

    describe "post deletion" do
      it "deletes posts marked for deletion" do
        post = create(:post)
        takedown = create(:takedown_with_post, post: post)
        takedown.update_columns(del_post_ids: post.id.to_s)
        perform(takedown)
        expect(post.reload.is_deleted?).to be true
      end

      it "skips posts that are already deleted" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        takedown = create(:takedown_with_post, post: post)
        takedown.update_columns(del_post_ids: post.id.to_s)
        expect { perform(takedown) }.not_to raise_error
        expect(post.reload.is_deleted?).to be true
      end
    end

    describe "post undeletion" do
      it "undeletes posts that should be kept but are currently deleted" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        takedown = create(:takedown_with_post, post: post)
        perform(takedown)
        expect(post.reload.is_deleted?).to be false
      end

      it "does not alter posts that should be kept and are not deleted" do
        post = create(:post)
        takedown = create(:takedown_with_post, post: post)
        expect { perform(takedown) }.not_to raise_error
        expect(post.reload.is_deleted?).to be false
      end
    end
  end
end
