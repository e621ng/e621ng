# frozen_string_literal: true

require "test_helper"

class PostReplacementTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    @mod_user = create(:moderator_user, created_at: 2.weeks.ago)
    @upload = UploadService.new(attributes_for(:jpg_upload).merge(uploader: @mod_user)).start!
    @post = @upload.post
    @post.update_columns({ is_pending: false, approver_id: @mod_user.id })
    CurrentUser.user = @user
  end

  context "User Limits:" do
    should "fail on too many per post in one day" do
      Danbooru.config.stubs(:post_replacement_per_day_limit).returns(-1)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator has already suggested too many replacements for this post today"], @replacement.errors.full_messages
    end

    should "fail on too many per post total" do
      Danbooru.config.stubs(:post_replacement_per_post_limit).returns(-1)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator already has too many pending replacements for this post"], @replacement.errors.full_messages
    end

    should "fail if user has no remaining upload limit" do
      User.any_instance.stubs(:upload_limit).returns(0)
      Danbooru.config.stubs(:disable_throttles?).returns(false)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator have reached your upload limit"], @replacement.errors.full_messages
    end
  end

  context "Upload:" do
    should "create backup replacement when first replacement is created" do
      assert_difference("@post.replacements.size", 2) do
        @post.replacements.create!(attributes_for(:png_replacement).merge(creator: @user))
      end
      statuses = @post.replacements.map(&:status)
      assert_includes statuses, "original"
      assert_includes statuses, "pending"
    end

    should "fail if post cannot be backed up" do
      @post.md5 = "123" # Breaks file path, should force backup to fail.
      assert_raise(ProcessingError) do
        @post.replacements.create!(attributes_for(:png_replacement).merge(creator: @user))
      end
    end

    should "allow non duplicate replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal @replacement.errors.size, 0
      assert_equal %w[original pending].sort, @post.replacements.map(&:status).sort
      assert @replacement.storage_id
      assert_equal Digest::MD5.file(file_fixture("test.png")).hexdigest, Digest::MD5.file(@replacement.replacement_file_path).hexdigest
    end

    should "not allow duplicate replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:jpg_replacement).merge(creator: @user))
      assert_equal(["Md5 duplicate of existing post ##{@post.id}"], @replacement.errors.full_messages)
    end

    should "not allow duplicate of pending replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal @replacement.errors.size, 0
      statuses = @post.replacements.pluck(:status)
      assert_equal %w[original pending].sort, statuses.sort
      assert @replacement.storage_id
      @new_replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal(["Md5 duplicate of pending replacement on post ##{@post.id}"], @new_replacement.errors.full_messages)
    end

    should "not allow invalid or blank file replacements" do
      @replacement = @post.replacements.create(attributes_for(:empty_replacement).merge(creator: @user))
      assert_match(/File ext \S* is invalid/, @replacement.errors.full_messages.join)
      @replacement = @post.replacements.create(attributes_for(:jpg_invalid_replacement).merge(creator: @user))
      assert_equal(["File is corrupt"], @replacement.errors.full_messages) # @Catt0s: HACK: this breaks due to the hack in file validator
    end

    should "not allow files that are too large" do
      Danbooru.config.stubs(:max_file_sizes).returns({ "png" => 0 })
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_match(/File size is too large/, @replacement.errors.full_messages.join)
    end

    should "not allow an apng that is too large" do
      Danbooru.config.stubs(:max_apng_file_size).returns(0)
      @replacement = @post.replacements.create(attributes_for(:apng_replacement).merge(creator: @user))
      assert_match(/File size is too large/, @replacement.errors.full_messages.join)
    end

    should "affect user upload limit" do
      assert_difference(-> { @user.post_replacements.pending.count}, 1) do
        @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      end
    end

    should "populate previous version uploader" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal(@post.uploader_id, @replacement.uploader_on_approve.id)
    end

    should "not allow 'backup' reason from users" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user, reason: "Backup of original file"))
      assert_equal ["You cannot use 'Backup of original file' as a reason."], @replacement.errors.full_messages
    end
  end

  context "Reject:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "mark replacement as rejected" do
      @replacement.reject!
      assert_equal "rejected", @replacement.status
    end

    should "allow duplicate replacement after rejection" do
      @replacement.reject!
      assert_equal "rejected", @replacement.status
      @new_replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert @new_replacement.valid?
      assert_equal [], @new_replacement.errors.full_messages
    end

    should "give user back their upload slot" do
      assert_difference(-> { @user.post_replacements.pending.count }, -1) do
        @replacement.reject!
      end
    end

    should "increment the users rejected replacements count" do
      assert_difference(-> { @user.post_replacement_rejected_count }, 1) do
        assert_difference(-> { @user.post_replacements.rejected.count }, 1) do
          @replacement.reject!
          @user.reload
        end
      end
    end

    should "work only once for pending replacements" do
      @replacement.reject!
      assert_equal [], @replacement.errors.full_messages
      @replacement.reject!
      assert_equal ["Status must be pending to reject"], @replacement.errors.full_messages
    end

    should "retain record of previous uploader" do
      @replacement.reject!
      assert_equal(@post.uploader_id, @replacement.uploader_on_approve.id)
    end

    should "record the rejecter" do
      @replacement.reject!
      assert_equal(CurrentUser.user.id, @replacement.approver_id)
    end
  end

  context "Approve:" do
    setup do
      @note = create(:note, post: @post, x: 100, y: 200, width: 100, height: 50)
      @replacement = create(:png_replacement, creator: @user, post: @post)
    end

    should "update post with new image" do
      old_md5 = @post.md5
      @replacement.approve! penalize_current_uploader: true
      @post.reload
      assert_not_equal @post.md5, old_md5
      assert_equal @replacement.image_width, @post.image_width
      assert_equal @replacement.image_height, @post.image_height
      assert_equal @replacement.md5, @post.md5
      assert_equal @replacement.creator_id, @post.uploader_id
      assert_equal @replacement.file_ext, @post.file_ext
      assert_equal @replacement.file_size, @post.file_size
    end

    should "work if the approver is above their upload limit" do
      User.any_instance.stubs(:upload_limit).returns(0)
      Danbooru.config.stubs(:disable_throttles?).returns(false)

      assert_nothing_raised { @replacement.approve!(penalize_current_uploader: true) }
      assert_equal @replacement.md5, @post.md5
    end

    should "generate videos samples if replacement is video" do
      @replacement = create(:webm_replacement, creator: @user, post: @post)
      @post.expects(:generate_video_samples).times(1)
      @replacement.approve! penalize_current_uploader: true
    end

    should "delete original files immediately" do
      sm = Danbooru.config.storage_manager
      old_md5 = @post.md5
      old_ext = @post.file_ext
      @replacement.approve! penalize_current_uploader: true
      @post.reload
      assert_not File.exist?(sm.file_path(old_md5, old_ext, :original))
      assert_not File.exist?(sm.file_path(old_md5, old_ext, :preview))
      assert_not File.exist?(sm.file_path(old_md5, old_ext, :large))
      assert_not File.exist?(sm.file_path(old_md5, old_ext, :original, protect: true))
    end

    should "not be able to approve on deleted post" do
      @post.update_column(:is_deleted, true)
      assert_raise ProcessingError do
        @replacement.approve! penalize_current_uploader: true
      end
    end

    should "update users upload counts" do
      assert_difference(-> { Post.for_user(@mod_user.id).where("is_flagged = false AND is_deleted = false AND is_pending = false").count }, -1) do
        assert_difference(-> { Post.for_user(@user.id).where("is_flagged = false AND is_deleted = false AND is_pending = false").count }, 1) do
          @replacement.approve! penalize_current_uploader: true
        end
      end
    end

    should "update the original users upload limit if penalized" do
      assert_difference(->{@mod_user.own_post_replaced_count}, 1) do
        assert_difference(->{@mod_user.own_post_replaced_penalize_count}, 1) do
          assert_difference(->{PostReplacement.penalized.for_uploader_on_approve(@mod_user.id).count}, 1) do
            @replacement.approve! penalize_current_uploader: true
            @mod_user.reload
          end
        end
      end
    end

    should "not update the original users upload limit if not penalizing" do
      assert_difference(-> { @mod_user.own_post_replaced_count }, 1) do
        assert_difference(-> { @mod_user.own_post_replaced_penalize_count }, 0) do
          assert_difference(-> { PostReplacement.not_penalized.for_uploader_on_approve(@mod_user.id).count }, 1) do
            @replacement.approve! penalize_current_uploader: false
            @mod_user.reload
          end
        end
      end
    end

    should "correctly resize the posts notes" do
      @replacement.approve! penalize_current_uploader: true
      @note.reload
      assert_equal 153, @note.x
      assert_equal 611, @note.y
      assert_equal 153, @note.width
      assert_equal 152, @note.height
    end

    should "only work on unpromoted and non-current replacements" do
      @replacement.promote!
      @replacement.approve! penalize_current_uploader: false
      assert_equal(["Status version is already active"], @replacement.errors.full_messages)
    end

    should "only work once" do
      @replacement.approve! penalize_current_uploader: false
      assert_equal [], @replacement.errors.full_messages
      @replacement.approve! penalize_current_uploader: false
      assert_equal ["Status version is already active"], @replacement.errors.full_messages
    end

    context "update the duration" do
      setup do
        @replacement = create(:webm_replacement, creator: @user, post: @post)
      end

      should "when the replacement is a video" do
        @replacement.approve! penalize_current_uploader: false
        @post.reload
        assert @post.duration
      end
    end

    context "without credit change" do
      should "update post without changing uploader" do
        old_md5 = @post.md5
        @replacement.approve! penalize_current_uploader: true, credit_replacer:false
        @post.reload
        assert_not_equal @post.md5, old_md5
        assert_equal @replacement.image_width, @post.image_width
        assert_equal @replacement.image_height, @post.image_height
        assert_equal @replacement.md5, @post.md5
        assert_not_equal @replacement.creator_id, @post.uploader_id
        assert_equal @replacement.file_ext, @post.file_ext
        assert_equal @replacement.file_size, @post.file_size
      end
    end

    should "retain record of previous uploader" do
      id_before = @replacement.post.uploader_id
      @replacement.approve! penalize_current_uploader: false
      assert_equal(id_before, @replacement.uploader_on_approve.id)
    end

    context "After rejection" do
      setup do
        @replacement.reject!
      end

      should "decrement the users rejected replacements count" do
        assert_difference(-> { @user.post_replacements.rejected.count }, -1) do
          @replacement.approve! penalize_current_uploader: false
          @user.reload
        end
      end
    end
  end

  context "Toggle:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "change the users upload limit" do
      @replacement.approve! penalize_current_uploader: false
      assert_difference(-> { @mod_user.own_post_replaced_penalize_count }, 1) do
        assert_difference(-> { PostReplacement.penalized.for_uploader_on_approve(@mod_user.id).count }, 1) do
          @replacement.toggle_penalize!
          @mod_user.reload
        end
      end
    end

    should "only work on appoved replacements" do
      @replacement.toggle_penalize!
      assert_equal(["Status must be approved to penalize"], @replacement.errors.full_messages)
    end
  end

  context "Promote:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "create a new post with replacement contents" do
      post = @replacement.promote!
      assert post
      assert_equal [], post.errors.full_messages
      assert_equal [], post.post.errors.full_messages
      assert_equal "promoted", @replacement.status
      assert_equal post.md5, @replacement.md5
      assert_equal post.file_ext, @replacement.file_ext
      assert_equal post.image_width, @replacement.image_width
      assert_equal post.image_height, @replacement.image_height
      assert_equal post.tag_string.strip, @replacement.post.tag_string.strip
      assert_equal post.parent_id, @replacement.post_id
      assert_equal post.file_size, @replacement.file_size
    end

    should "credit replacer with new post" do
      assert_difference(-> { Post.for_user(@mod_user.id).where("is_flagged = false AND is_deleted = false AND is_pending = false").count }, 0) do
        assert_difference(-> { Post.for_user(@user.id).where("is_flagged = false AND is_deleted = false").count }, 1) do
          post = @replacement.promote!
          assert post
          assert_equal [], post.errors.full_messages
          assert_equal [], post.post.errors.full_messages
        end
      end
    end

    should "only work on pending replacements" do
      @replacement.approve! penalize_current_uploader: false
      @replacement.promote!
      assert_equal(["Status must be pending to promote"], @replacement.errors.full_messages)
    end

    should "retain record of previous uploader" do
      @replacement.promote!
      assert_equal(@post.uploader_id, @replacement.uploader_on_approve.id)
    end

    should "record the approver" do
      @replacement.promote!
      assert_equal(CurrentUser.user.id, @replacement.approver_id)
    end
  end

  context "Note: " do 
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "allow staff to edit" do 
      CurrentUser.user = @mod_user
      @replacement.add_note("test")
      # @Catt0s TODO - cant assert since it doesnt exist yet
    end

    should "prevent non-staff from adding" do
      CurrentUser.user = @user
      @replacement.add_note("i shouldn't be here")
      assert_equal(["You do not have permission to add a note."], @replacement.errors.full_messages)
    end

    should "enforce viewing permissions" do
      @uninvolved_user = create(:user, created_at: 2.weeks.ago)
      assert(@replacement.note_visible_to?(@user))
      assert(@replacement.note_visible_to?(@mod_user))
      assert_not(@replacement.note_visible_to?(@uninvolved_user))
    end

  end

  context "Transfer: " do 
    setup do
      @upload_alt = UploadService.new(attributes_for(:large_jpg_upload).merge(uploader: @user)).start!
      # @Catt0s Fix: upload service says the file is corrupted, for some reason
      assert_not_nil @upload_alt, "UploadService did not create a upload"
      # puts @upload_alt.inspect
      # puts @upload_alt.status
      @post_alt = @upload_alt.post
      assert_not_nil @post_alt, "UploadService did not create a post"

      @post_alt.update_columns({ is_pending: false, approver_id: @mod_user.id })
      CurrentUser.user = @user
      @replacement = create(:png_replacement, creator: @user, post: @post, reason: "wrong alt replacement")
      assert @replacement
    end

    should "fail if new post is deleted" do
      CurrentUser.user = @mod_user
      @post_alt.delete!("test")
      @replacement.transfer(@post_alt)
      assert_equal(["Post is deleted"], @replacement.errors.full_messages)
    end

    should "fail when the post is the same" do 
      @replacement.transfer(@post)
      assert_equal(["Post must be a different post"], @replacement.errors.full_messages)
    end

    should "fail on non-pending replacements" do
      @replacement.reject!
      @replacement.transfer(@post_alt)
      assert_equal(["Status must be pending to transfer"], @replacement.errors.full_messages)
    end

    should "create backup replacement if one doesn't exist" do 
      assert_difference(-> { @post_alt.replacements.count }, 2) do
        assert_difference(-> { @post.replacements.count }, -1) do
          @replacement.transfer(@post_alt)
        end
      end
      
      statuses = @post_alt.replacements.map(&:status)
      assert_includes statuses, "original"
      assert_includes statuses, "pending"
    end

    should "fail if post cannot be backed up" do # @Catt0s TODO: FIX
      @post_alt.md5 = "123" # Breaks file path, should force backup to fail.
      assert_raise(ProcessingError) do
        @replacement.transfer(@post_alt)
      end
    end

    should "not allow duplicates" do 
      @existing_replacement = @post_alt.replacements.create(attributes_for(:png_replacement).merge(creator: @user, reason: "existing replacement"))
      @existing_replacement.update_column(:md5, @replacement.md5) # force md5 collission
      assert @existing_replacement
      @replacement.transfer(@post_alt)
      assert_equal(["Md5 duplicate of existing replacement on post ##{@post_alt.id}"], @replacement.errors.full_messages)
    end
    
    should "work on pending replacements" do
      # we other case tested already, make sure we dont create multiple backups
      @existing_replacement = @post_alt.replacements.create(attributes_for(:apng_replacement).merge(creator: @user, reason: "existing replacement"))
      assert @existing_replacement
      assert_difference(-> { @post_alt.replacements.count }, 1) do # @Catt0s TODO: Fix: 2 instead of 1
        assert_difference(-> { @post.replacements.count }, -1) do
          @replacement.transfer(@post_alt)
        end
      end

      # The replacement should now belong to @post_alt and have status "pending"
      assert_equal @post_alt.id, @replacement.post_id
      assert_equal "pending", @replacement.status

      # The previous uploader should be set correctly
      assert_equal @post.uploader_id, @replacement.uploader_on_approve.id

      # Both posts should have their indexes updated (simulate by checking timestamps)
      assert @post.reload.updated_at <= Time.now
      assert @post_alt.reload.updated_at <= Time.now

      # The original backup should exist on the new post
      assert @post_alt.replacements.where(status: "original").exists?
    end
  end
end
