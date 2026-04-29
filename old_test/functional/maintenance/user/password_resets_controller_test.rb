# frozen_string_literal: true

require "test_helper"

module Maintenance
  module User
    class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
      context "A password resets controller" do
        setup do
          @user = create(:user, :email => "abc@com.net")
          ActionMailer::Base.delivery_method = :test
          ActionMailer::Base.deliveries.clear
        end

        should "render the new page" do
          get new_maintenance_user_password_reset_path
          assert_response :success
        end

        context "create action" do
          context "given invalid parameters" do
            setup do
              post maintenance_user_password_reset_path, params: {:nonce => {:email => ""}}
            end

            should "not create a new nonce" do
              assert_equal(0, UserPasswordResetNonce.count)
            end

            should "redirect to the new page" do
              assert_redirected_to new_maintenance_user_password_reset_path
            end

            should "not deliver an email" do
              assert_equal(0, ActionMailer::Base.deliveries.size)
            end
          end

          context "given valid parameters" do
            setup do
              post maintenance_user_password_reset_path, params: { email: @user.email }
            end

            should "create a new nonce" do
              assert_equal(1, UserPasswordResetNonce.where(user: @user).count)
            end

            should "redirect to the new page" do
              assert_redirected_to new_maintenance_user_password_reset_path
            end

            should "deliver an email to the supplied email address" do
              assert_equal(1, ActionMailer::Base.deliveries.size)
            end
          end
        end

        context "edit action" do
          context "with invalid parameters" do
            setup do
              get edit_maintenance_user_password_reset_path, params: {:email => "a@b.c"}
            end

            should "succeed silently" do
              assert_response :success
            end
          end

          context "with valid parameters" do
            setup do
              @user = create(:user)
              @nonce = create(:user_password_reset_nonce, user: @user)
              ActionMailer::Base.deliveries.clear
              get edit_maintenance_user_password_reset_path, params: {uid: @user.id, key: @nonce.key}
            end

            should "succeed" do
              assert_response :success
            end
          end

          context "with uid containing non-numeric characters (translation software)" do
            setup do
              @user = create(:user)
              @nonce = create(:user_password_reset_nonce, user: @user)
              ActionMailer::Base.deliveries.clear
              # Simulate Chinese translation appending text to the UID
              get edit_maintenance_user_password_reset_path, params: { uid: "#{@user.id}关闭网页", key: @nonce.key }
            end

            should "succeed by sanitizing the uid" do
              assert_response :success
              # Should render the form, not show "Invalid reset" message
              assert_select "h1", text: "Reset Password"
              assert_select "input[type=password]"
            end
          end
        end

        context "update action" do
          context "with valid parameters" do
            setup do
              @user = create(:user)
              @nonce = create(:user_password_reset_nonce, user: @user)
              ActionMailer::Base.deliveries.clear
              @old_password = @user.bcrypt_password_hash
              put maintenance_user_password_reset_path, params: { uid: @user.id.to_s, key: @nonce.key, password: "test", password_confirm: "test" }
            end

            should "succeed" do
              assert_redirected_to new_maintenance_user_password_reset_path
            end

            should "change the password" do
              @user.reload
              assert_not_equal(@old_password, @user.bcrypt_password_hash)
            end

            should "delete the nonce" do
              assert_equal(0, UserPasswordResetNonce.count)
            end
          end

          context "with uid containing non-numeric characters (translation software)" do
            setup do
              @user = create(:user)
              @nonce = create(:user_password_reset_nonce, user: @user)
              ActionMailer::Base.deliveries.clear
              @old_password = @user.bcrypt_password_hash
              # Simulate Chinese translation appending text to the UID
              put maintenance_user_password_reset_path, params: { uid: "#{@user.id}关闭网页", key: @nonce.key, password: "newpass123", password_confirm: "newpass123" }
            end

            should "succeed by sanitizing the uid" do
              assert_redirected_to new_maintenance_user_password_reset_path
            end

            should "change the password despite the extra characters" do
              @user.reload
              assert_not_equal(@old_password, @user.bcrypt_password_hash)
            end

            should "delete the nonce" do
              assert_equal(0, UserPasswordResetNonce.count)
            end
          end
        end
      end
    end
  end
end
