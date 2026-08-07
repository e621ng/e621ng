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

    it "penalizes the previous uploader's karma when turning the penalty on" do
      prev_uploader = create(:user)
      replacement = create(:approved_post_replacement)
                    .tap { |r| r.update_columns(penalize_uploader_on_approve: false, uploader_id_on_approve: prev_uploader.id) }
      allow(PostEvent).to receive(:add)
      expect { replacement.toggle_penalize! }
        .to change { prev_uploader.user_status.reload.upload_karma }.by(-UserStatus::KARMA_REPLACEMENT_PENALTY)
    end

    it "reverses the previous uploader's karma penalty when turning the penalty off" do
      prev_uploader = create(:user)
      replacement = create(:approved_post_replacement)
                    .tap { |r| r.update_columns(penalize_uploader_on_approve: true, uploader_id_on_approve: prev_uploader.id) }
      allow(PostEvent).to receive(:add)
      expect { replacement.toggle_penalize! }
        .to change { prev_uploader.user_status.reload.upload_karma }.by(UserStatus::KARMA_REPLACEMENT_PENALTY)
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
    let(:post_main)   { create(:post) }
    let(:post_alt)    { create(:post) }
    let(:replacement) { create(:post_replacement, post: post_main) }

    before do
      # The transfer reindexes both posts on commit; keep OpenSearch out of it.
      allow(post_main).to receive(:update_index)
      allow(post_alt).to receive(:update_index)
    end

    # Seed the destination with an original so create_original_backup is a no-op (no
    # file I/O) — the same guard the real before_create relies on.
    def seed_destination_backup
      create(:original_post_replacement, post: post_alt)
    end

    context "guards" do
      it "fails when the replacement is neither pending nor rejected" do
        replacement.update_columns(status: "approved")
        replacement.transfer(post_alt)
        expect(replacement.errors[:status]).to include("must be pending or rejected to transfer")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end

      it "fails when the destination is the same post" do
        replacement.transfer(post_main)
        expect(replacement.errors[:post]).to include("must be a different post")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end

      it "fails when the destination is deleted" do
        post_alt.update_columns(is_deleted: true)
        replacement.transfer(post_alt)
        expect(replacement.errors[:post]).to include("is deleted")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end

      it "fails when the replacement is identical to the destination's current file" do
        replacement.update_columns(md5: post_alt.md5)
        replacement.transfer(post_alt)
        expect(replacement.errors[:md5]).to include("identical to the destination post's current file")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end

      it "fails when the destination already holds a replacement with this md5" do
        create(:post_replacement, post: post_alt, md5: replacement.md5)
        replacement.transfer(post_alt)
        expect(replacement.errors[:md5]).to include("duplicate of existing replacement on post ##{post_alt.id}")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end
    end

    context "when the move succeeds" do
      before { seed_destination_backup }

      it "moves the replacement to the destination post" do
        replacement.transfer(post_alt)
        expect(replacement.reload.post_id).to eq(post_alt.id)
        expect(replacement.errors).to be_empty
      end

      it "does not add a second original when the destination already has one" do
        replacement.is_backup = false # so the skip is the existing-original guard, not the flag
        expect { replacement.transfer(post_alt) }
          .not_to(change { post_alt.replacements.where(status: "original").count })
      end

      it "recomputes the sequence number for the destination, avoiding a collision" do
        # post_alt already has an original (seq 0) plus a replacement at seq 1 — the same
        # number the record carries. Without a recompute this collides on the UNIQUE
        # (post_id, sequence_number) index.
        create(:post_replacement, post: post_alt) # occupies seq 1
        expect(replacement.sequence_number).to eq(1)

        expect { replacement.transfer(post_alt) }.not_to raise_error
        expect(replacement.reload.post_id).to eq(post_alt.id)
        expect(replacement.sequence_number).to eq(2)
      end

      it "preserves a pending status" do
        replacement.transfer(post_alt)
        expect(replacement.reload.status).to eq("pending")
      end

      it "preserves a rejected status without touching the rejection count" do
        rejected = create(:rejected_post_replacement, post: post_main)
        expect { rejected.transfer(post_alt) }
          .not_to(change { rejected.creator.user_status.reload.post_replacement_rejected_count })
        expect(rejected.reload.status).to eq("rejected")
        expect(rejected.post_id).to eq(post_alt.id)
      end

      it "re-derives uploader_on_approve to the destination's uploader" do
        replacement.transfer(post_alt)
        expect(replacement.reload.uploader_id_on_approve).to eq(post_alt.uploader_id)
      end

      it "clears penalize when the destination uploader is the replacement's creator" do
        post_alt.update_columns(uploader_id: replacement.creator_id)
        replacement.update_columns(penalize_uploader_on_approve: true)
        replacement.transfer(post_alt)
        expect(replacement.reload.penalize_uploader_on_approve).to be false
      end

      it "records a replacement_moved event on both posts" do
        allow(PostEvent).to receive(:add)
        replacement.transfer(post_alt)
        expect(PostEvent).to have_received(:add).with(post_alt.id, CurrentUser.user, :replacement_moved, hash_including(old_post: post_main.id, new_post: post_alt.id))
        expect(PostEvent).to have_received(:add).with(post_main.id, CurrentUser.user, :replacement_moved, hash_including(old_post: post_main.id, new_post: post_alt.id))
      end
    end

    context "when the destination has no original backup" do
      # Exercise the real create_original_backup; stub only the file I/O it performs
      # (the post factory stores no real file on disk). storage_manager is rebuilt on
      # every call, so pin one instance and route the config through it.
      before do
        storage = Danbooru.config.storage_manager
        allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
        allow(storage).to receive(:open).and_return(File.open(file_fixture("sample.jpg")))
        allow(storage).to receive(:store_replacement)
        allow(ImageSampler).to receive(:generate_replacement_images)
        allow(FileValidator).to receive(:new).and_return(instance_double(FileValidator, validate: nil))
        # The factory sets is_backup: true, which short-circuits create_original_backup;
        # a real transfer runs on a record found fresh, with the flag unset.
        replacement.is_backup = false
      end

      it "creates an original (seq 0) backup on the destination" do
        expect { replacement.transfer(post_alt) }
          .to change { post_alt.replacements.where(status: "original").count }.from(0).to(1)

        backup = post_alt.replacements.find_by(status: "original")
        expect(backup.sequence_number).to eq(0)
        expect(backup.md5).to be_present
        expect(replacement.reload.post_id).to eq(post_alt.id)
      end
    end

    context "when the destination backup fails" do
      it "rolls back and reports when create_original_backup raises a ProcessingError" do
        allow(replacement).to receive(:create_original_backup).and_raise(ProcessingError.new("boom"))
        replacement.transfer(post_alt)
        expect(replacement.errors.full_messages).to include("Failed to create backup on the destination post: boom")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end

      it "rolls back gracefully when create_original_backup throws :abort" do
        allow(replacement).to receive(:create_original_backup) do
          replacement.errors.add(:base, "Failed to create backup: boom")
          throw :abort
        end
        expect { replacement.transfer(post_alt) }.not_to raise_error
        expect(replacement.errors.full_messages).to include("Failed to create backup: boom")
        expect(replacement.reload.post_id).to eq(post_main.id)
      end
    end
  end
end
