require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  context "Admin::UsersController" do
    setup do
      @user = create(:user)
      @admin = create(:admin_user, is_bd_staff: true)
    end

    context "#edit" do
      should "render" do
        get_auth edit_admin_user_path(@user), @admin
        assert_response :success
      end
    end

    context "#update" do
      context "on a basic user" do
        should "fail for moderators" do
          put_auth admin_user_path(@user), create(:moderator_user), params: { user: { level: "30" } }
          assert_response :forbidden
        end

        should "succeed" do
          put_auth admin_user_path(@user), @admin, params: { user: { level: "30" } }
          assert_redirected_to(user_path(@user))
          @user.reload
          assert_equal(30, @user.level)
        end

        should "rename" do
          assert_difference(-> { ModAction.count }, 1) do
            put_auth admin_user_path(@user), @admin, params: { user: { name: "renamed" } }
            assert_redirected_to(user_path(@user))
            assert_equal("renamed", @user.reload.name)
          end
        end
      end

      context "on an user with a blank email" do
        setup do
          @user = create(:user, email: "")
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
        end

        should "succeed" do
          put_auth admin_user_path(@user), @admin, params: { user: { level: "30" } }
          assert_redirected_to(user_path(@user))
          @user.reload
          assert_equal(30, @user.level)
        end

        should "prevent invalid emails" do
          put_auth admin_user_path(@user), @admin, params: { user: { email: "invalid" } }
          @user.reload
          assert_equal("", @user.email)
        end
      end

      context "on a user with duplicate email" do
        setup do
          @user1 = create(:user, email: "test@e621.net")
          @user2 = create(:user, email: "test@e621.net")
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
        end

        should "allow editing if the email is not changed" do
          put_auth admin_user_path(@user1), @admin, params: { user: { level: "30" } }
          @user1.reload
          assert_equal(30, @user1.level)
        end

        should "allow changing the email" do
          put_auth admin_user_path(@user1), @admin, params: { user: { email: "abc@e621.net" } }
          @user1.reload
          assert_equal("abc@e621.net", @user1.email)
        end
      end
    end
  end
end
