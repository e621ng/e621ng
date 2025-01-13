# frozen_string_literal: true

require "test_helper"

module Maintenance
  module User
    class ApiKeysControllerTest < ActionDispatch::IntegrationTest
      context "An api keys controller" do
        setup do
          @user = create(:privileged_user, password: "6cQE!wbA")
          @api_key = ApiKey.generate!(@user)
        end

        context "show action" do
          should "let a user see their own API keys" do
            get_auth maintenance_user_api_key_path(@user.id), @user
            assert_response :success
            assert_select "#api-key-#{@api_key.id}", count: 1
          end

          should "not let a user see API keys belonging to other users" do
            get_auth maintenance_user_api_key_path(@user.id), create(:user)
            assert_response :success
            assert_select "#api-key-#{@api_key.id}", count: 0
          end

          should "redirect to the confirm password page if the user hasn't recently authenticated" do
            post session_path, params: { session: { name: @user.name, password: @user.password } }
            travel_to 2.hours.from_now do
              get maintenance_user_api_key_path(@user.id)
            end
            assert_redirected_to confirm_password_session_path(url: maintenance_user_api_key_path(@user.id))
          end
        end

        context "update action" do
          should "regenerate the API key" do
            old_key = @user.api_key
            put_auth maintenance_user_api_key_path, @user
            assert_not_equal(old_key.key, @user.reload.api_key.key)
          end
        end

        context "destroy action" do
          should "delete the API key" do
            delete_auth maintenance_user_api_key_path, @user
            assert_nil(@user.reload.api_key)
          end
        end
      end
    end
  end
end
