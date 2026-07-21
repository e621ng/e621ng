# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   PostReplacement::ProcessingMethods                        #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  # --------------------------------------------------------------------------
  # #reject!
  # --------------------------------------------------------------------------
  describe "#reject!" do
    it "sets status to 'rejected'" do
      replacement = create(:post_replacement)
      allow(PostEvent).to receive(:add)
      allow(replacement.post).to receive(:update_index)
      replacement.reject!
      expect(replacement.reload.status).to eq("rejected")
    end

    it "sets approver_id to the current user" do
      replacement = create(:post_replacement)
      allow(PostEvent).to receive(:add)
      allow(replacement.post).to receive(:update_index)
      replacement.reject!
      expect(replacement.reload.approver_id).to eq(CurrentUser.user.id)
    end

    it "adds an error and does not change status when replacement is not pending" do
      replacement = create(:approved_post_replacement)
      replacement.reject!
      expect(replacement.errors[:status]).to be_present
      expect(replacement.reload.status).to eq("approved")
    end

    it "fires a replacement_rejected PostEvent" do
      replacement = create(:post_replacement)
      allow(replacement.post).to receive(:update_index)
      allow(PostEvent).to receive(:add)
      replacement.reject!
      expect(PostEvent).to have_received(:add).with(
        replacement.post.id,
        CurrentUser.user,
        :replacement_rejected,
        hash_including(replacement_id: replacement.id),
      )
    end
  end

  # --------------------------------------------------------------------------
  # #approve!
  # --------------------------------------------------------------------------
  describe "#approve!" do
    def stub_approve_deps(replacement)
      allow(FileValidator).to receive(:new).and_return(instance_double(FileValidator, "validator", validate: nil))
      allow(PostEvent).to receive(:add)
      allow(replacement.post).to receive(:update_index)
    end

    it "adds an error when the replacement md5 matches the post (is_current?)" do
      post = create(:post)
      replacement = create(:post_replacement, post: post, md5: post.md5)
      replacement.approve!(penalize_current_uploader: false)
      expect(replacement.errors[:status]).to include("version is already active")
    end

    it "adds an error when the replacement is already promoted" do
      replacement = create(:promoted_post_replacement)
      replacement.approve!(penalize_current_uploader: false)
      expect(replacement.errors[:status]).to include("version is already active")
    end

    it "delegates to UploadService::Replacer" do
      post = create(:post)
      replacement = create(:post_replacement, post: post)
      stub_approve_deps(replacement)

      processor = instance_double(UploadService::Replacer, process!: nil)
      allow(UploadService::Replacer).to receive(:new)
        .with(post: replacement.post, replacement: replacement)
        .and_return(processor)

      replacement.approve!(penalize_current_uploader: true)

      expect(UploadService::Replacer).to have_received(:new)
        .with(post: replacement.post, replacement: replacement)
      expect(processor).to have_received(:process!).with(penalize_current_uploader: true)
    end

    it "returns early without delegating when FileValidator finds errors" do
      post = create(:post)
      replacement = create(:post_replacement, post: post)
      validator = instance_double(FileValidator)
      allow(FileValidator).to receive(:new).and_return(validator)
      allow(validator).to receive(:validate) { replacement.errors.add(:base, "bad file") }
      allow(UploadService::Replacer).to receive(:new)

      replacement.approve!(penalize_current_uploader: false)

      expect(UploadService::Replacer).not_to have_received(:new)
    end
  end

  # --------------------------------------------------------------------------
  # #toggle_penalize!
  # --------------------------------------------------------------------------
  describe "#toggle_penalize!" do
    it "adds an error when status is not 'approved'" do
      replacement = create(:post_replacement) # pending
      replacement.toggle_penalize!
      expect(replacement.errors[:status]).to include("must be approved to penalize")
    end

    it "flips penalize_uploader_on_approve from false to true" do
      replacement = create(:approved_post_replacement)
                    .tap { |r| r.update_columns(penalize_uploader_on_approve: false) }
      allow(PostEvent).to receive(:add)
      replacement.toggle_penalize!
      expect(replacement.reload.penalize_uploader_on_approve).to be true
    end

    it "flips penalize_uploader_on_approve from true to false" do
      replacement = create(:approved_post_replacement)
                    .tap { |r| r.update_columns(penalize_uploader_on_approve: true) }
      allow(PostEvent).to receive(:add)
      replacement.toggle_penalize!
      expect(replacement.reload.penalize_uploader_on_approve).to be false
    end

    it "fires a replacement_penalty_changed PostEvent" do
      replacement = create(:approved_post_replacement)
                    .tap { |r| r.update_columns(penalize_uploader_on_approve: false) }
      allow(PostEvent).to receive(:add)
      replacement.toggle_penalize!
      expect(PostEvent).to have_received(:add).with(
        replacement.post.id,
        CurrentUser.user,
        :replacement_penalty_changed,
        hash_including(replacement_id: replacement.id),
      )
    end
  end

  # --------------------------------------------------------------------------
  # #promote!
  # --------------------------------------------------------------------------
  describe "#promote!" do
    it "adds an error when status is 'approved' and replacement is current" do
      post = create(:post)
      replacement = create(:approved_post_replacement, post: post, md5: post.md5)
      replacement.promote!
      expect(replacement.errors[:status]).to include("must be pending to promote")
    end

    it "adds an error when status is 'original'" do
      replacement = create(:original_post_replacement)
      replacement.promote!
      expect(replacement.errors[:status]).to include("must be pending to promote")
    end

    it "delegates to UploadService for a pending replacement" do
      replacement = create(:post_replacement, status: "pending")
      upload = build_stubbed(:upload, status: "completed")
      post_double = instance_double(Post, valid?: true, id: 999)
      allow(upload).to receive_messages(
        post: post_double,
        valid?: true,
      )

      processor = instance_double(UploadService, start!: upload)
      allow(UploadService).to receive(:new).and_return(processor)
      allow(replacement).to receive(:new_upload_params).and_return({})
      allow(PostEvent).to receive(:add)
      allow(replacement.post).to receive(:update_index)

      replacement.promote!

      expect(processor).to have_received(:start!)
    end

    it "delegates to UploadService for a rejected replacement" do
      replacement = create(:rejected_post_replacement)
      upload = build_stubbed(:upload, status: "completed")
      post_double = instance_double(Post, valid?: true, id: 999)
      allow(upload).to receive_messages(
        post: post_double,
        valid?: true,
      )

      processor = instance_double(UploadService, start!: upload)
      allow(UploadService).to receive(:new).and_return(processor)
      allow(replacement).to receive(:new_upload_params).and_return({})
      allow(PostEvent).to receive(:add)
      allow(replacement.post).to receive(:update_index)

      replacement.promote!

      expect(processor).to have_received(:start!)
    end
  end

  # --------------------------------------------------------------------------
  # #transfer
  # --------------------------------------------------------------------------
  describe "#transfer" do
    let(:post_main) { create(:post) }
    let(:post_alt) { create(:post) }
    let(:replacement) { create(:post_replacement, post: post_main) }

    before do
      # If this isn't here, it doesn't work.
      replacement.reload
      post_main.reload
    end

    it "fail if new post is deleted" do
      post_alt.update_columns(is_deleted: true)
      replacement.transfer(post_alt)
      expect(replacement.errors.full_messages).to eq(["Post is deleted"])
    end

    it "fails when the post is the same" do
      replacement.transfer(post_main)
      expect(replacement.errors.full_messages).to eq(["Post must be a different post"])
    end

    it "fails on replacements that are not pending or rejected" do
      replacement.update_columns(status: "approved")
      replacement.transfer(post_alt)
      expect(replacement.errors.full_messages).to eq(["Status must be pending or rejected to transfer"])
    end

    it "creates backup replacement if one doesn't exist" do
      allow(replacement).to receive(:create_original_backup)
      # What changes during the transfer
      expect do
        expect do
          replacement.transfer(post_alt) # Transfer the replacement
        end.to change { post_alt.replacements.count }.by(1) # 2 total, but backup is skipped
      end.to change { post_main.replacements.count }.by(-1)
      # Check that a call to create the original was made
      expect(replacement).to have_received(:create_original_backup)

      statuses = post_alt.replacements.map(&:status)
      expect(statuses).to include("pending") # We don't expect an original status since it isn't actually created
    end

    it "Does not work on backups" do
      backup = create(:original_post_replacement, post: post_main, md5: post_main.md5)
      backup.transfer(post_alt)
      expect(backup.errors.full_messages).to eq(["Status must be pending or rejected to transfer"])
      expect(backup.post_id).to eq(post_main.id)
    end

    it "does not allow duplicates" do
      existing_replacement = create(:post_replacement, post: post_alt, md5: replacement.md5)
      existing_replacement.update_columns(status: "rejected")

      replacement.transfer(post_alt)
      expect(replacement.errors.full_messages).to eq(["Md5 duplicate of existing replacement on post ##{post_alt.id}"])
      expect(replacement.post_id).to eq(post_main.id)
    end

    it "work on pending replacements" do
      # Fake a backup or the original since it isn't supported in tests.
      existing_replacement = create(:post_replacement, post: post_alt, md5: post_alt.md5)
      existing_replacement.update_columns(status: "original")

      # What changes during the transfer
      expect do
        expect do
          replacement.transfer(post_alt)
        end.to change { post_alt.replacements.count }.by(1) # Post alt gains a replacement
      end.to change { post_main.replacements.count }.by(-1) # Orignal post loses a replacement

      expect(replacement.post_id).to eq(post_alt.id)
      expect(replacement.status).to eq("pending")
      expect(replacement.uploader_on_approve).to eq(post_alt.uploader)

      expect(post_main.reload.updated_at).to be <= Time.now
      expect(post_alt.reload.updated_at).to be <= Time.now
      expect(post_alt.replacements.where(status: "original").exists?).to be true
    end

    it "work on rejected replacements without resetting status" do
      # Fake a backup or the original since it isn't supported in tests.
      existing_replacement = create(:post_replacement, post: post_alt)
      existing_replacement.update_columns(status: "original")
      replacement.update_columns(status: "rejected")

      # What changes during the transfer
      expect do
        expect do
          replacement.transfer(post_alt)
        end.to change { post_alt.replacements.count }.by(1) # The replacement is moved (backup creation skipped)
      end.to change { post_main.replacements.count }.by(-1) # Orignal post loses a replacement

      replacement.reload

      expect(replacement.post_id).to eq(post_alt.id)
      expect(replacement.status).to eq("rejected")
      expect(replacement.uploader_on_approve).to eq(post_alt.uploader)
      expect(post_alt.replacements.where(status: "original").exists?).to be true
    end

    it "add an error if backup creation fails during transfer" do
      allow(replacement).to receive(:create_original_backup).and_raise(ProcessingError.new("boom"))

      expect do
        replacement.transfer(post_alt)
      end.not_to(change { post_alt.replacements.where(status: "original").count })

      expect(replacement.errors.full_messages).to include("Failed to create backup on new post: boom")
    end
  end
end
