# frozen_string_literal: true

require "test_helper"

module Maintenance
  module User
    class EmailChangesControllerTest < ActionDispatch::IntegrationTest
      context "in all cases" do
        setup do
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
          @user = create(:user, email: "bob@ogres.net")
        end

        context "#new" do
          should "render" do
            get_auth new_maintenance_user_email_change_path, @user
            assert_response :success
          end
        end

        context "#create" do
          context "with the correct password" do
            should "work" do
              post_auth maintenance_user_email_change_path, @user, params: { email_change: { password: "password", email: "abc@ogres.net" } }
              assert_redirected_to(home_users_path)
              @user.reload
              assert_equal("abc@ogres.net", @user.email)
            end
          end

          context "with the incorrect password" do
            should "not work" do
              post_auth maintenance_user_email_change_path, @user, params: { email_change: { password: "passwordx", email: "abc@ogres.net" } }
              @user.reload
              assert_equal("bob@ogres.net", @user.email)
            end
          end

          should "not work with an invalid email" do
            post_auth maintenance_user_email_change_path, @user, params: { email_change: { password: "password", email: "" } }
            @user.reload
            assert_not_equal("", @user.email)
            assert_match(/Email can't be blank/, flash[:notice])
          end

          should "work with a valid email when the users current email is invalid" do
            @user = create(:user, email: "")
            post_auth maintenance_user_email_change_path, @user, params: { email_change: { password: "password", email: "abc@ogres.net" } }
            @user.reload
            assert_equal("abc@ogres.net", @user.email)
          end
        end
      end
    end
  end
end
