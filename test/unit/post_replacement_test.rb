require 'test_helper'

class PostReplacementTest < ActiveSupport::TestCase
  setup do
    Timecop.travel(2.weeks.ago) do
      @user = FactoryBot.create(:user)
      @mod_user = FactoryBot.create(:moderator_user)
    end
    @upload = UploadService.new(FactoryBot.attributes_for(:jpg_upload).merge(uploader: @mod_user, uploader_ip_addr: '127.0.0.1')).start!
    @post = @upload.post
    @post.update_columns({is_pending: false, approver_id: @mod_user.id})
    CurrentUser.user = @user
    CurrentUser.ip_addr = "127.0.0.1"
  end

  teardown do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context "User Limits:" do
    should "fail on too many per post in one day" do
      Danbooru.config.stubs(:post_replacement_per_day_limit).returns(-1)
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal ['Creator has already suggested too many replacements for this post today'], @replacement.errors.full_messages
    end

    should "fail on too many per post total" do
      Danbooru.config.stubs(:post_replacement_per_post_limit).returns(-1)
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal ['Creator has already suggested too many total replacements for this post'], @replacement.errors.full_messages
    end

    should "fail if user has no remaining upload limit" do
      User.any_instance.stubs(:upload_limit).returns(0)
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal ['Creator have reached your upload limit'], @replacement.errors.full_messages
    end

    should "fail if user has no remaining replacements" do
      User.any_instance.stubs(:can_replace_post_with_reason).returns(:REJ_LIMITED)
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal ['Creator have reached the hourly limit for this action'], @replacement.errors.full_messages
    end
  end

  context "Upload:" do
    should "allow non duplicate replacement submission" do
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal @replacement.errors.size, 0
      assert_equal @post.replacements.size, 1
      assert_equal @replacement.status, 'pending'
      assert @replacement.storage_id
      assert_equal Digest::MD5.file("#{Rails.root}/test/files/test.png").hexdigest, Digest::MD5.file(@replacement.replacement_file_path).hexdigest
    end

    should "not allow duplicate replacement submission" do
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:jpg_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal(["Md5 duplicate of existing post ##{@post.id}"], @replacement.errors.full_messages)
    end

    should "not allow duplicate of pending replacement submission" do
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal @replacement.errors.size, 0
      assert_equal @post.replacements.size, 1
      assert_equal @replacement.status, 'pending'
      assert @replacement.storage_id
      @new_replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal(["Md5 duplicate of pending replacement on post ##{@post.id}"], @new_replacement.errors.full_messages)
    end

    should "not allow invalid or blank file replacements" do
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:empty_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal(["Unknown or invalid file format"], @replacement.errors.full_messages)
      @replacement = @post.replacements.create(FactoryBot.attributes_for(:jpg_invalid_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert_equal(["Unknown or invalid file format"], @replacement.errors.full_messages)
    end

    should "affect user upload limit" do
      assert_difference("PostReplacement.pending.for_user(@user.id).count", 1) do
        @replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      end
    end
  end

  context "Reject:" do
    setup do
      @replacement = FactoryBot.create(:png_replacement, creator: @user, creator_ip_addr: '127.0.0.1', post: @post)
      assert @replacement
    end

    should "mark replacement as rejected" do
      @replacement.reject!
      assert_equal 'rejected', @replacement.status
    end

    should "allow duplicate replacement after rejection" do
      @replacement.reject!
      assert_equal 'rejected', @replacement.status
      @new_replacement = @post.replacements.create(FactoryBot.attributes_for(:png_replacement).merge(creator: @user, creator_ip_addr: '127.0.0.1'))
      assert @new_replacement.valid?
      assert_equal [], @new_replacement.errors.full_messages
    end

    should "create a mod action" do
      assert_difference("ModAction.count") do
        @replacement.reject!
      end
    end

    should "give user back their upload slot" do
      assert_difference("PostReplacement.pending.for_user(@user.id).count", -1) do
        @replacement.reject!
      end
    end
  end

  context "Approve:" do
    setup do
      @replacement = FactoryBot.create(:png_replacement, creator: @user, creator_ip_addr: '127.0.0.1', post: @post)
      assert @replacement
    end

    should "create a mod action" do
      assert_difference("ModAction.count") do
        @replacement.approve!
      end
    end

    should "fail if post cannot be backed up" do
      @post.md5 = "123" # Breaks file path, should force backup to fail.
      assert_raise(ProcessingError) do
        @replacement.approve!
      end
    end

    should "create comment on post signaling replacement" do
      assert_difference("@post.comments.count", 1) do
        @replacement.approve!
      end
    end

    should "update post with new image" do
      old_md5 = @post.md5
      @replacement.approve!
      @post.reload
      assert_not_equal @post.md5, old_md5
      assert_equal @replacement.image_width, @post.image_width
      assert_equal @replacement.image_height, @post.image_height
      assert_equal @replacement.md5, @post.md5
      assert_equal @replacement.creator_id, @post.uploader_id
      assert_equal @replacement.file_ext, @post.file_ext
      assert_equal @replacement.file_size, @post.file_size
    end

    should "generate videos samples if replacement is video" do
      @replacement = FactoryBot.create(:webm_replacement, creator: @user, creator_ip_addr: '127.0.0.1', post: @post)
      @post.expects(:generate_video_samples).times(1)
      @replacement.approve!
    end

    should "delete original files immediately" do
      sm = Danbooru.config.storage_manager
      old_md5 = @post.md5
      old_ext = @post.file_ext
      @replacement.approve!
      @post.reload
      assert_not File.exists?(sm.file_path(old_md5, old_ext, :original))
      assert_not File.exists?(sm.file_path(old_md5, old_ext, :preview))
      assert_not File.exists?(sm.file_path(old_md5, old_ext, :large))
      assert_not File.exists?(sm.file_path(old_md5, old_ext, :original, protected=true))
    end

    should "not be able to approve on deleted post" do
      @post.update_column(:is_deleted, true)
      assert_raise ProcessingError do
        @replacement.approve!
      end
    end

    should "create backup replacement" do
      old_md5 = @post.md5
      old_source = @post.source
      assert_difference("@post.replacements.size", 1) do
        @replacement.approve!
      end
      new_replacement = @post.replacements.last
      assert_equal 'original', new_replacement.status
      assert_equal old_md5, new_replacement.md5
      assert_equal old_source, new_replacement.source
      assert_equal old_md5, Digest::MD5.file(new_replacement.replacement_file_path).hexdigest
    end

    should "update users upload counts" do
      assert_difference("Post.for_user(@mod_user.id).where('is_flagged = false AND is_deleted = false AND is_pending = false').count", -1) do
        assert_difference("Post.for_user(@user.id).where('is_flagged = false AND is_deleted = false AND is_pending = false').count", 1) do
          @replacement.approve!
        end
      end
    end
  end

  context "Promote:" do
    setup do
      @replacement = FactoryBot.create(:png_replacement, creator: @user, creator_ip_addr: '127.0.0.1', post: @post)
      assert @replacement
    end

    should "create a new post with replacement contents" do

    end
  end
end
