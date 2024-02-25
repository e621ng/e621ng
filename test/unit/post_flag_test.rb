# frozen_string_literal: true

require "test_helper"

class PostFlagTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      travel_to(2.weeks.ago) do
        @bob = create(:user)
        @alice = create(:privileged_user)
      end
      as(@alice) do
        @post = create(:post, tag_string: "aaa", uploader: @alice)
      end
    end

    should "respect the throttle limit" do
      as(@bob) do
        Danbooru.config.stubs(:disable_throttles?).returns(false)
        Danbooru.config.stubs(:post_flag_limit).returns(0)

        error = assert_raises(ActiveRecord::RecordInvalid) do
          @post_flag = create(:post_flag, post: @post)
        end
        assert_match(/You have reached the hourly limit for this action/, error.message)
      end
    end

    should "not be able to flag a deleted post" do
      as(@alice) do
        @post.update(is_deleted: true)
      end

      error = assert_raises(ActiveRecord::RecordInvalid) do
        as(@bob) do
          @post_flag = create(:post_flag, post: @post)
        end
      end
      assert_match(/Post is deleted/, error.message)
    end

    should "not be able to flag a non-pending post with the uploading_guidelines reason" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        as(@bob) do
          @post_flag = create(:post_flag, post: @post, reason_name: "uploading_guidelines")
        end
      end
      assert_match(/not pending/, error.message)

      @post = create(:post, is_pending: true)
      as(@bob) do
        @post_flag = create(:post_flag, post: @post, reason_name: "uploading_guidelines")
      end
    end

    should "not be able to flag a post in the cooldown period" do
      @mod = create(:moderator_user)

      @users = create_list(:user, 2, created_at: 2.weeks.ago)

      as(@users.first) do
        @flag1 = create(:post_flag, post: @post)
      end

      as(@mod) do
        @post.approve!
      end

      travel_to(PostFlag::COOLDOWN_PERIOD.from_now - 1.minute) do
        as(@users.second) do
          error = assert_raises(ActiveRecord::RecordInvalid) do
            @flag2 = create(:post_flag, post: @post)
          end
          assert_match(/cannot be flagged more than once/, error.message)
        end
      end

      travel_to(PostFlag::COOLDOWN_PERIOD.from_now + 1.minute) do
        as(@users.second) do
          @flag3 = create(:post_flag, post: @post)
        end
        assert(@flag3.errors.empty?)
      end
    end

    should "initialize its creator" do
      @post_flag = as(@alice) do
        create(:post_flag, post: @post)
      end
      assert_equal(@alice.id, @post_flag.creator_id)
      assert_equal(IPAddr.new("127.0.0.1"), @post_flag.creator_ip_addr)
    end

    context "a user with no_flag=true" do
      setup do
        @bob = create(:user, no_flagging: true, created_at: 2.weeks.ago)
      end

      should "not be able to flag" do
        error = assert_raises(ActiveRecord::RecordInvalid) do
          as(@bob) { create(:post_flag, post: @post) }
        end
        assert_match(/You cannot flag posts/, error.message)
      end
    end
  end
end
