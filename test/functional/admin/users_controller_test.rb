require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  context "Admin::UsersController" do
    setup do
      @user = create(:user)
      @admin = create(:admin_user)
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
      end

      context "on an user with a blank email" do
        setup do
          @user = create(:user, email: "")
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
        end

        should "succeed" do
          put_auth admin_user_path(@user), @admin, params: { user: { level: "20", email: "" } }
          assert_redirected_to(user_path(@user))
          @user.reload
          assert_equal(20, @user.level)
        end

        should "prevent invalid emails" do
          put_auth admin_user_path(@user), @admin, params: { user: { level: "10", email: "invalid" } }
          @user.reload
          assert_equal("", @user.email)
        end
      end
    end
  end
end
