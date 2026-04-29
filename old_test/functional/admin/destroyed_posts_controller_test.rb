# frozen_string_literal: true

require "test_helper"

module Admin
  class DestroyedPostsControllerTest < ActionDispatch::IntegrationTest
    context "The destroyed posts controller" do
      setup do
        @admin = create(:admin_user)
        @bd_staff = create(:bd_staff_user)
        @upload = UploadService.new(attributes_for(:jpg_upload).merge({ uploader: @admin })).start!
        @post = @upload.post
        as(@admin) { @post.expunge! }
        @destroyed_post = DestroyedPost.find_by!(post_id: @post.id)
      end

      context "index action" do
        should "render" do
          get_auth admin_destroyed_posts_path, @admin
          assert_response :success
        end
      end

      context "show action" do
        should "redirect" do
          get_auth admin_destroyed_post_path(@post), @admin
          assert_redirected_to(admin_destroyed_posts_path(search: { post_id: @post.id }))
        end
      end

      context "update action" do
        should "work" do
          assert_difference("StaffAuditLog.count", 1) do
            put_auth admin_destroyed_post_path(@post), @bd_staff, params: { destroyed_post: { notify: "false" } }
            assert_redirected_to(admin_destroyed_posts_path)
            assert_equal(false, @destroyed_post.reload.notify)
            assert_equal("disable_post_notifications", StaffAuditLog.last.action)
          end

          assert_difference("StaffAuditLog.count", 1) do
            put_auth admin_destroyed_post_path(@post), @bd_staff, params: { destroyed_post: { notify: "true" } }
            assert_redirected_to(admin_destroyed_posts_path)
            assert_equal(true, @destroyed_post.reload.notify)
            assert_equal("enable_post_notifications", StaffAuditLog.last.action)
          end
        end
      end
    end
  end
end
