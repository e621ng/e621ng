# frozen_string_literal: true

require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  context "The api keys controller" do
    setup do
      @user = create(:user)
      @other_user = create(:user)
      @admin = create(:admin_user)
      @api_key = create(:api_key, user: @user, name: "test_key")
    end

    context "index action" do
      should "let a user see their own API keys" do
        get_auth(api_keys_path, @user)
        assert_response(:success)
        assert_includes(response.body, @api_key.key)
      end

      should "redirect to the confirm password page if the user hasn't recently authenticated" do
        post(session_path, params: { session: { name: @user.name, password: @user.password } })
        travel_to(2.hours.from_now) do
          get(api_keys_path)
        end

        assert_redirected_to(confirm_password_session_path(url: api_keys_path))
      end
    end

    context "new action" do
      should "render for a Member user" do
        get_auth(new_api_key_path, @user)
        assert_response(:success)
      end

      should "fail for an Anonymous user" do
        get(new_api_key_path)
        assert_redirected_to(new_session_path(url: new_api_key_path))
      end
    end

    context "create action" do
      should "create a new API key" do
        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "new_key" } })
        end

        api_key = ApiKey.last
        assert_equal("new_key", api_key.name)
        assert_equal(@user, api_key.user)
        assert_redirected_to(api_keys_path)
      end

      should "create API key with duration" do
        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "week_key", duration: "7" } })
        end

        api_key = ApiKey.last
        assert_equal("week_key", api_key.name)
        assert_in_delta(7.days.from_now.to_i, api_key.expires_at.to_i, 60)
      end

      should "create API key which never expires" do
        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "permanent_key", duration: "never" } })
        end

        api_key = ApiKey.last
        assert_equal("permanent_key", api_key.name)
        assert_nil(api_key.expires_at)
      end

      should "create API key with custom expiration" do
        expiry_date = 2.months.from_now

        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "custom_key", duration: "custom", expires_at: expiry_date } })
        end

        api_key = ApiKey.last
        assert_equal("custom_key", api_key.name)
        assert_equal(expiry_date.to_date, api_key.expires_at.to_date)
      end

      should "create API key with empty custom duration" do
        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "no_date_key", duration: "custom" } })
        end

        api_key = ApiKey.last
        assert_equal("no_date_key", api_key.name)
        assert_nil(api_key.expires_at)
        assert_redirected_to(api_keys_path)
      end

      should "fail with duplicate name for same user" do
        assert_no_difference("ApiKey.count") do
          post_auth(api_keys_path, @user, params: { api_key: { name: "test_key" } })
        end

        assert_response(:success)
        assert_match(/Name has already been taken/, @response.body)
      end

      should "fail with empty name" do
        assert_no_difference("ApiKey.count") do
          post_auth(api_keys_path, @user, params: { api_key: { name: "" } })
        end

        assert_response(:success)
        assert_match(/Name can&#39;t be blank/, @response.body)
      end
    end

    context "destroy action" do
      should "delete the user's API key" do
        assert_difference("ApiKey.count", -1) do
          delete_auth(api_key_path(@api_key), @user)
        end

        assert_redirected_to(api_keys_path)
        assert_raises(ActiveRecord::RecordNotFound) { @api_key.reload }
      end

      should "not allow deleting another user's API key" do
        assert_no_difference("ApiKey.count") do
          delete_auth(api_key_path(@api_key), @other_user)
        end

        assert_response(:not_found)
        assert_not_nil(@api_key.reload)
      end
    end
  end
end
