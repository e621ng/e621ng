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

      should "create API key with expiration date" do
        expiry_date = 1.month.from_now.to_date

        assert_difference("ApiKey.count", 1) do
          post_auth(api_keys_path, @user, params: { api_key: { name: "expiring_key", expires_at: expiry_date } })
        end

        api_key = ApiKey.last
        assert_equal("expiring_key", api_key.name)
        assert_equal(expiry_date.to_time.to_date, api_key.expires_at.to_date)
      end

      should "fail with duplicate name for same user" do
        assert_no_difference("ApiKey.count") do
          post_auth(api_keys_path, @user, params: { api_key: { name: "test_key" } })
        end

        assert_response(:success) # Should render new template with errors
        assert_match(/Name has already been taken/, response.body)
      end
    end

    context "edit action" do
      should "render for the API key owner" do
        get_auth(edit_api_key_path(@api_key), @user)
        assert_response(:success)
      end

      should "fail for someone else" do
        get_auth(edit_api_key_path(@api_key), @other_user)
        assert_response(:not_found)
      end
    end

    context "update action" do
      should "update the API key for the owner" do
        put_auth(api_key_path(@api_key), @user, params: { api_key: { name: "updated_name" } })

        assert_redirected_to(api_keys_path)
        assert_equal("updated_name", @api_key.reload.name)
      end

      should "fail for someone else" do
        put_auth(api_key_path(@api_key), @other_user, params: { api_key: { name: "hacked" } })

        assert_response(:not_found)
        assert_equal("test_key", @api_key.reload.name)
      end

      should "fail with duplicate name" do
        create(:api_key, user: @user, name: "other_key")
        put_auth(api_key_path(@api_key), @user, params: { api_key: { name: "other_key" } })

        assert_response(:success) # Should render edit template with errors
        assert_match(/Name has already been taken/, response.body)
        assert_equal("test_key", @api_key.reload.name)
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
