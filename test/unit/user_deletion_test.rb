# frozen_string_literal: true

require "test_helper"

class UserDeletionTest < ActiveSupport::TestCase
  context "an invalid user deletion" do
    context "for an invalid password" do
      setup do
        @user = create(:user)
        CurrentUser.user = @user
        @deletion = UserDeletion.new(@user, "wrongpassword")
      end

      should "fail" do
        assert_raise(UserDeletion::ValidationError) do
          @deletion.delete!
        end
      end
    end

    context "for an admin" do
      setup do
        @user = create(:admin_user)
        CurrentUser.user = @user
        @deletion = UserDeletion.new(@user, "6cQE!wbA")
      end

      should "fail" do
        assert_raise(UserDeletion::ValidationError) do
          @deletion.delete!
        end
      end
    end
  end

  context "a valid user deletion" do
    setup do
      @user = create(:privileged_user, created_at: 2.weeks.ago)
      CurrentUser.user = @user

      @post = create(:post)
      FavoriteManager.add!(user: @user, post: @post)

      @user.update(email: "ted@danbooru.com")

      @deletion = UserDeletion.new(@user, "6cQE!wbA")
      with_inline_jobs { @deletion.delete! }
      @user.reload
    end

    should "blank out the email" do
      assert_empty(@user.email)
    end

    should "rename the user" do
      assert_equal("user_#{@user.id}", @user.name)
    end

    should "reset the password" do
      assert_raises(BCrypt::Errors::InvalidHash) do
        User.authenticate(@user.name, "6cQE!wbA")
      end
    end

    should "reset the level" do
      assert_equal(User::Levels::MEMBER, @user.level)
    end

    should "remove any favorites" do
      @post.reload
      assert_equal(0, Favorite.count)
      assert_equal("", @post.fav_string)
      assert_equal(0, @post.fav_count)
    end
  end
end
