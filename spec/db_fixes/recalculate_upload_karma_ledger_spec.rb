# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/142_recalculate_upload_karma_ledger")

RSpec.describe Fixes::RecalculateUploadKarmaLedger do
  include_context "as admin"

  let(:uploader) { create(:user) }
  let(:approver) { create(:moderator_user) }

  # db/seeds.rb writes staff_override rows for the admin/system users, which would
  # trip the script's must-run-first guard. Cleared per example (transactional).
  before { UploadKarmaEvent.delete_all }

  def run!
    described_class.run
  end

  it "refuses to run when the ledger already has rows" do
    create(:upload_karma_event)
    expect { run! }.to raise_error(/not empty/)
  end

  describe "live posts" do
    it "credits an approved post to the uploader with the approver as creator" do
      post = create(:post, uploader: uploader)
      post.update_columns(approver_id: approver.id)

      run!

      event = UploadKarmaEvent.find_by(post_id: post.id)
      expect(event).to have_attributes(
        user_id: uploader.id,
        creator_id: approver.id,
        reason: "approved",
        delta: UserStatus::KARMA_APPROVED_CREDIT,
        extra_data: { "backfill" => true },
      )
      expect(uploader.user_status.reload.upload_karma).to eq(UserStatus::KARMA_APPROVED_CREDIT)
    end

    it "records a post without any approval trace as queue_bypass, dated at post creation" do
      post = create(:post, uploader: uploader)

      run!

      event = UploadKarmaEvent.find_by(post_id: post.id)
      expect(event).to have_attributes(user_id: uploader.id, creator_id: uploader.id, reason: "queue_bypass")
      expect(event.created_at).to be_within(1.second).of(post.created_at)
    end

    it "dates an approved post from its approval event" do
      post = create(:post, uploader: uploader)
      post.update_columns(approver_id: approver.id)
      create(:post_event, post_id: post.id, creator: approver, action: :approved, created_at: 3.days.ago)

      run!

      event = UploadKarmaEvent.find_by(post_id: post.id)
      expect(event.reason).to eq("approved")
      expect(event.created_at).to be_within(1.second).of(3.days.ago)
    end

    it "ignores pending posts" do
      create(:pending_post, uploader: uploader)
      run!
      expect(UploadKarmaEvent.count).to eq(0)
    end
  end

  describe "deleted posts" do
    it "records only the net deletion penalty, even for a previously approved post" do
      post = create(:deleted_post, uploader: uploader)
      post.update_columns(approver_id: approver.id)

      run!

      events = UploadKarmaEvent.where(post_id: post.id)
      expect(events.count).to eq(1)
      expect(events.first).to have_attributes(reason: "deleted", delta: -UserStatus::KARMA_DELETION_PENALTY)
      expect(uploader.user_status.reload.upload_karma).to eq(-UserStatus::KARMA_DELETION_PENALTY)
    end

    it "dates the penalty from the deletion event and attributes it to the deleter" do
      post = create(:deleted_post, uploader: uploader)
      create(:post_event, post_id: post.id, creator: approver, action: :deleted, created_at: 2.days.ago)

      run!

      event = UploadKarmaEvent.find_by(post_id: post.id)
      expect(event.creator_id).to eq(approver.id)
      expect(event.created_at).to be_within(1.second).of(2.days.ago)
    end

    it "falls back to created_at for ancient posts with no deletion trace and a NULL updated_at" do
      post = create(:deleted_post, uploader: uploader)
      post.update_columns(created_at: 10.years.ago, updated_at: nil)

      run!

      event = UploadKarmaEvent.find_by(post_id: post.id)
      expect(event.reason).to eq("deleted")
      expect(event.created_at).to be_within(1.second).of(10.years.ago)
    end

    it "skips takedown-deleted posts" do
      post = create(:post, uploader: uploader)
      create(:post_deletion, post: post, reason: "takedown #123: artist request")
      post.update_columns(is_deleted: true, is_pending: false)

      run!

      expect(UploadKarmaEvent.count).to eq(0)
      expect(uploader.user_status.reload.upload_karma).to eq(0)
    end
  end

  describe "replacement penalties" do
    it "records outstanding penalties for approved and original replacements" do
      approved = create(:approved_post_replacement, uploader_id_on_approve: uploader.id, penalize_uploader_on_approve: true)
      original = create(:original_post_replacement, uploader_id_on_approve: uploader.id, penalize_uploader_on_approve: true)
      create(:approved_post_replacement, uploader_id_on_approve: uploader.id, penalize_uploader_on_approve: false)

      run!

      events = UploadKarmaEvent.where(reason: :replacement_penalty)
      expect(events.pluck(:post_id)).to contain_exactly(approved.post_id, original.post_id)
      expect(events.pluck(:delta).uniq).to eq([-UserStatus::KARMA_REPLACEMENT_PENALTY])
    end
  end

  describe "ordering and balances" do
    it "inserts rows so ids ascend with created_at" do
      newer = create(:post, uploader: uploader)
      older = create(:post, uploader: create(:user))
      newer.update_columns(created_at: 1.day.ago)
      older.update_columns(created_at: 5.days.ago)

      run!

      timestamps = UploadKarmaEvent.order(:id).pluck(:created_at)
      expect(timestamps).to eq(timestamps.sort)
    end

    it "computes per-user running balances and sets the final balance from the sum" do
      live = create(:post, uploader: uploader)
      live.update_columns(created_at: 5.days.ago)
      deleted = create(:deleted_post, uploader: uploader)
      create(:post_event, post_id: deleted.id, creator: approver, action: :deleted, created_at: 1.day.ago)

      run!

      expect(UploadKarmaEvent.where(user_id: uploader.id).order(:id).pluck(:balance)).to eq([1, -2])
      expect(uploader.user_status.reload.upload_karma).to eq(-2)
    end

    it "resets stale nonzero balances for users with no ledger rows" do
      uploader.user_status.update_columns(upload_karma: 50)

      run!

      expect(uploader.user_status.reload.upload_karma).to eq(0)
    end
  end
end
