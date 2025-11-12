# frozen_string_literal: true

require "test_helper"

class TransferFavoritesJobTest < ActiveJob::TestCase
  context "TransferFavoritesJob" do
    setup do
      @user = create(:user)
      @parent = create(:post)
      @child = create(:post, parent: @parent)
      CurrentUser.user = @user
    end

    should "remove the favorites_transfer_in_progress flag after successful transfer" do
      favorite_user = create(:user)
      FavoriteManager.add!(user: favorite_user, post: @child)

      assert_not @child.favorites_transfer_in_progress?
      assert_not @parent.favorites_transfer_in_progress?

      TransferFavoritesJob.new.perform(@child.id, @user.id)

      @child.reload
      @parent.reload

      assert_not @child.favorites_transfer_in_progress?, "Child should not have transfer flag after job completes"
      assert_not @parent.favorites_transfer_in_progress?, "Parent should not have transfer flag after job completes"
      assert_equal(1, @parent.fav_count)
      assert_equal(0, @child.fav_count)
    end

    should "remove the flags even if the parent is deleted during transfer" do
      favorite_user = create(:user)
      FavoriteManager.add!(user: favorite_user, post: @child)

      # Simulate parent being deleted mid-execution by stubbing reload to raise RecordNotFound
      @parent.stubs(:reload).raises(ActiveRecord::RecordNotFound)

      TransferFavoritesJob.new.perform(@child.id, @user.id)

      @child.reload
      assert_not @child.favorites_transfer_in_progress?, "Child should not have transfer flag even when parent reload fails"
    end

    should "remove the flags even if the child is deleted during transfer" do
      favorite_user = create(:user)
      FavoriteManager.add!(user: favorite_user, post: @child)

      # Simulate child being deleted mid-execution by stubbing reload to raise RecordNotFound
      @child.stubs(:reload).raises(ActiveRecord::RecordNotFound)

      TransferFavoritesJob.new.perform(@child.id, @user.id)

      @parent.reload
      assert_not @parent.favorites_transfer_in_progress?, "Parent should not have transfer flag even when child reload fails"
    end

    should "not fail if the post doesn't exist" do
      assert_nothing_raised do
        TransferFavoritesJob.new.perform(999_999, @user.id)
      end
    end

    should "not fail if the user doesn't exist" do
      assert_nothing_raised do
        TransferFavoritesJob.new.perform(@child.id, 999_999)
      end
    end
  end

  context "Post.cleanup_stuck_favorite_transfer_flags!" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
    end

    should "clean up all posts with stuck flags" do
      post = create(:post)
      transfer_flag = Post.flag_value_for("favorites_transfer_in_progress")

      # Set the flag
      post.update_columns(bit_flags: post.bit_flags | transfer_flag)

      assert post.reload.favorites_transfer_in_progress?, "Flag should be set initially"

      count = Post.cleanup_stuck_favorite_transfer_flags!

      assert_equal(1, count)
      assert_not post.reload.favorites_transfer_in_progress?, "Flag should be cleaned up"
    end

    should "handle multiple stuck posts" do
      posts = create_list(:post, 3)
      transfer_flag = Post.flag_value_for("favorites_transfer_in_progress")

      posts.each do |post|
        post.update_columns(bit_flags: post.bit_flags | transfer_flag)
      end

      count = Post.cleanup_stuck_favorite_transfer_flags!

      assert_equal(3, count)
      posts.each do |post|
        assert_not post.reload.favorites_transfer_in_progress?, "All flags should be cleaned up"
      end
    end

    should "return 0 when no stuck flags exist" do
      create(:post)
      count = Post.cleanup_stuck_favorite_transfer_flags!
      assert_equal(0, count)
    end
  end
end
