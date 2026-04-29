# frozen_string_literal: true

require "test_helper"

class PostApprovalTest < ActiveSupport::TestCase
  context "a pending post" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user

      @post = create(:post, uploader_id: @user.id, tag_string: "touhou", is_pending: true)

      @approver = create(:user)
      @approver.can_approve_posts = true
      @approver.save
      CurrentUser.user = @approver
    end

    should "allow approval" do
      assert_equal(false, @post.approved_by?(@approver))
    end

    context "That is approved" do
      should "not create a postapproval record when approved by the uploader" do
        assert_no_difference("PostApproval.count") do
          @post.approve!(@post.uploader)
        end
      end

      should "create a postapproval record when approved by someone else" do
        assert_difference("PostApproval.count") do
          @post.approve!(create(:janitor_user))
        end
      end
    end

    context "#search method" do
      should "work" do
        @post.approve!(@approver)
        @approvals = PostApproval.search(user_name: @approver.name, post_tags_match: "touhou", post_id: @post.id.to_s)

        assert_equal([@post.id], @approvals.map(&:post_id))
      end
    end
  end
end
