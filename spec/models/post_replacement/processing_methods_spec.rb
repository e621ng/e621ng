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
end
