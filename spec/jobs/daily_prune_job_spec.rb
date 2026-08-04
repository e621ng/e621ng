# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyPruneJob do
  describe "#perform" do
    it "runs every prune task" do
      allow(Setting).to receive(:disable_exception_prune?).and_return(false)
      allow(TagAlias).to receive(:update_cached_post_counts_for_all)
      allow(Tag).to receive(:clean_up_negative_post_counts!)
      allow(Ban).to receive(:prune!)
      allow(UserPasswordResetNonce).to receive(:prune!)
      allow(ExceptionLog).to receive(:prune!)
      allow(Post).to receive(:cleanup_stuck_favorite_transfer_flags!)

      described_class.perform_now

      expect(TagAlias).to have_received(:update_cached_post_counts_for_all)
      expect(Tag).to have_received(:clean_up_negative_post_counts!)
      expect(Ban).to have_received(:prune!)
      expect(UserPasswordResetNonce).to have_received(:prune!)
      expect(ExceptionLog).to have_received(:prune!)
      expect(Post).to have_received(:cleanup_stuck_favorite_transfer_flags!)
    end

    it "deletes uploads older than the deletion window" do
      old_upload = create(:upload, created_at: (Danbooru.config.upload_deletion_window + 1.day).ago)
      new_upload = create(:upload)

      described_class.perform_now

      expect(Upload.exists?(old_upload.id)).to be(false)
      expect(Upload.exists?(new_upload.id)).to be(true)
    end

    it "skips the exception log prune when disabled" do
      allow(Setting).to receive(:disable_exception_prune?).and_return(true)
      allow(ExceptionLog).to receive(:prune!)

      described_class.perform_now

      expect(ExceptionLog).not_to have_received(:prune!)
    end

    it "continues running later tasks when an earlier one fails" do
      error = StandardError.new("boom")
      allow(TagAlias).to receive(:update_cached_post_counts_for_all).and_raise(error)
      allow(DanbooruLogger).to receive(:log)
      allow(Post).to receive(:cleanup_stuck_favorite_transfer_flags!)

      described_class.perform_now

      expect(DanbooruLogger).to have_received(:log).with(error)
      expect(Post).to have_received(:cleanup_stuck_favorite_transfer_flags!)
    end
  end
end
