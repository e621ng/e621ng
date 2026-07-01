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
# LEGACY TEST VERSION: 
#   context "Transfer: " do
#   setup do
#     @user_alt = create(:user, created_at: 2.weeks.ago)
#     @upload_alt = UploadService.new(attributes_for(:large_jpg_upload).merge(uploader: @user_alt)).start!
#     assert_not_nil @upload_alt, "UploadService did not create an alt upload"
#     @post_alt = @upload_alt.post
#     assert_not_nil(@post_alt, "UploadService did not create an alt post: #{@upload.status}")

#     @post_alt.update_columns({ is_pending: false, approver_id: @mod_user.id })
#     CurrentUser.user = @user
#     @replacement = create(:png_replacement, creator: @user, post: @post, reason: "wrong alt replacement")
#     assert @replacement
#   end

#   should "fail if new post is deleted" do
#     CurrentUser.user = @mod_user
#     @post_alt.delete!("test")
#     @replacement.transfer(@post_alt)
#     assert_equal(["Post is deleted"], @replacement.errors.full_messages)
#   end

#   should "fail when the post is the same" do
#     @replacement.transfer(@post)
#     assert_equal(["Post must be a different post"], @replacement.errors.full_messages)
#   end

#   should "fail on replacements that are not pending or rejected" do
#     @replacement.approve! penalize_current_uploader: false
#     @replacement.transfer(@post_alt)
#     assert_equal(["Status must be pending or rejected to transfer"], @replacement.errors.full_messages)
#   end

#   should "create backup replacement if one doesn't exist" do
#     assert_difference(-> { @post_alt.replacements.count }, 2) do
#       assert_difference(-> { @post.replacements.count }, -1) do
#         @replacement.transfer(@post_alt)
#       end
#     end

#     statuses = @post_alt.replacements.map(&:status)
#     assert_includes statuses, "original"
#     assert_includes statuses, "pending"
#   end

#   should "not allow duplicates" do
#     @existing_replacement = @post_alt.replacements.create(attributes_for(:png_replacement).merge(creator: @user, reason: "existing replacement", md5: @replacement.md5))
#     assert_not_nil @existing_replacement
#     @existing_replacement.reject!
#     @existing_replacement.save!
#     @replacement.transfer(@post_alt)
#     assert_equal(["Md5 duplicate of existing replacement on post ##{@post_alt.id}"], @replacement.errors.full_messages)
#   end

#   should "work on pending replacements" do
#     @existing_replacement = @post_alt.replacements.create(attributes_for(:apng_replacement).merge(creator: @user, reason: "existing replacement"))
#     assert_not_nil @existing_replacement
#     @existing_replacement.reject!
#     assert_difference(-> { @post_alt.replacements.count }, 1) do
#       assert_difference(-> { @post.replacements.count }, -1) do
#         @replacement.transfer(@post_alt)
#       end
#     end

#     # The replacement should now belong to @post_alt and have status "pending"
#     assert_equal @post_alt.id, @replacement.post_id
#     assert_equal "pending", @replacement.status

#     # The previous uploader should be set correctly
#     assert_equal @post_alt.uploader_id, @replacement.uploader_on_approve.id

#     # Both posts should have their indexes updated (simulate by checking timestamps)
#     assert @post.reload.updated_at <= Time.now
#     assert @post_alt.reload.updated_at <= Time.now

#     # The original backup should exist on the new post
#     assert @post_alt.replacements.where(status: "original").exists?
#   end

#   should "work on rejected replacements without resetting status" do
#     @replacement.reject!

#     assert_difference(-> { @post_alt.replacements.count }, 2) do
#       assert_difference(-> { @post.replacements.count }, -1) do
#         @replacement.transfer(@post_alt)
#       end
#     end

#     @replacement.reload

#     assert_equal @post_alt.id, @replacement.post_id
#     assert_equal "rejected", @replacement.status
#     assert_equal @post_alt.uploader_id, @replacement.uploader_on_approve.id
#     assert @post_alt.replacements.where(status: "original").exists?
#   end

#   should "add an error if backup creation fails during transfer" do
#     @replacement.stubs(:create_original_backup).raises(ProcessingError.new("boom"))

#     assert_no_difference(-> { @post_alt.replacements.where(status: "original").count }) do
#       @replacement.transfer(@post_alt)
#     end

#     assert_includes @replacement.errors.full_messages, "Failed to create backup on new post: boom"
#   end
  end
end
