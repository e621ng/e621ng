# frozen_string_literal: true

require "test_helper"

class UserNameChangeRequestsControllerTest < ActionDispatch::IntegrationTest
  context "The user name change requests controller" do
    setup do
      @user = create(:privileged_user)
      @original_name = @user.name
      @admin = create(:admin_user)
    end

    context "new action" do
      should "render successfully for authenticated users" do
        get_auth new_user_name_change_request_path, @user
        assert_response :success
      end

      should "render for a user with a currently invalid username" do
        @user.update_columns(name: "12345")
        get_auth new_user_name_change_request_path, @user
        assert_response :success
      end

      should "redirect anonymous users to login" do
        get new_user_name_change_request_path
        assert_redirected_to(%r{session/new})
      end
    end

    context "create action" do
      should "create request and immediately change user name" do
        assert_difference(-> { UserNameChangeRequest.count }, 1) do
          post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "newname" } }
        end

        change_request = UserNameChangeRequest.last
        assert_redirected_to user_name_change_request_path(change_request)
        @user.reload
        assert_equal("newname", @user.name)
        assert_equal(@original_name, change_request.original_name)
        assert_equal("newname", change_request.desired_name)
      end

      should "work for users with currently invalid names" do
        @user.update_columns(name: "12345")
        post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "validname" } }

        change_request = UserNameChangeRequest.last
        assert_redirected_to user_name_change_request_path(change_request)
        assert_equal("validname", @user.reload.name)
      end

      should "allow changing capitalization" do
        new_name = @user.name.capitalize
        post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: new_name } }

        assert_response :redirect
        assert_equal(new_name, @user.reload.name)
      end

      should "handle validation errors" do
        create(:user, name: "taken")

        post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "taken" } }

        assert_response :success # Should render new template with errors
        assert_equal(@original_name, @user.reload.name) # Name should not change
        assert_select ".error-messages", text: /already exists/
      end

      should "enforce rate limiting" do
        # First request should work
        post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "firstchange" } }
        assert_response :redirect
        assert_equal("firstchange", @user.reload.name)

        # Second request within a week should fail
        post_auth user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "secondchange" } }
        assert_response :success # Should render form with errors
        assert_equal("firstchange", @user.reload.name) # Name should not change
        assert_select ".error-messages", text: /one name change request per week/
      end

      should "require authentication" do
        post user_name_change_requests_path, params: { user_name_change_request: { desired_name: "newname" } }
        assert_redirected_to(%r{session/new})
      end
    end

    context "show action" do
      setup do
        as(@user) do
          @change_request = UserNameChangeRequest.create(desired_name: "uniquename#{rand(10_000)}", skip_limited_validation: true)
          @user.reload
        end
      end

      should "render for the request owner" do
        get_auth user_name_change_request_path(@change_request), @user
        assert_response :success
        assert_select "h1", text: /Name Change Request/
      end

      should "render for admins" do
        get_auth user_name_change_request_path(@change_request), @admin
        assert_response :success
      end

      should "deny access to other users" do
        other_user = create(:user)
        get_auth user_name_change_request_path(@change_request), other_user
        assert_response :forbidden
      end

      should "require authentication" do
        get user_name_change_request_path(@change_request)
        assert_redirected_to(/session\/new/)
      end
    end

    context "index action" do
      setup do
        as(@user) { @request1 = UserNameChangeRequest.create(desired_name: "name1", skip_limited_validation: true) }
        other_user = create(:user)
        as(other_user) { @request2 = UserNameChangeRequest.create(desired_name: "name2", skip_limited_validation: true) }
      end

      should "render for admins" do
        get_auth user_name_change_requests_path, @admin
        assert_response :success
        assert_select "h1", text: /Name Change Requests/
      end

      should "deny access to regular users" do
        regular_user = create(:user)
        get_auth user_name_change_requests_path, regular_user
        assert_response :forbidden
      end

      should "support search filtering" do
        get_auth user_name_change_requests_path, @admin, params: { search: { original_name: @user.name } }
        assert_response :success
        assert_select "tr", count: 2 # Header + 1 matching result
      end

      should "require authentication" do
        get user_name_change_requests_path
        assert_redirected_to(/session\/new/)
      end
    end

    context "destroy action" do
      setup do
        as(@user) do
          @change_request = UserNameChangeRequest.new(desired_name: "deleteme")
          @change_request.skip_limited_validation = true
          @change_request.save!
        end
      end

      should "allow admins to delete requests" do
        assert_difference(-> { UserNameChangeRequest.count }, -1) do
          delete_auth user_name_change_request_path(@change_request), @admin
        end
        assert_redirected_to user_name_change_requests_path
      end

      should "deny access to regular users" do
        regular_user = create(:user)
        assert_no_difference(-> { UserNameChangeRequest.count }) do
          delete_auth user_name_change_request_path(@change_request), regular_user
        end
        assert_response :forbidden
      end

      should "deny access to other users" do
        other_user = create(:user)
        assert_no_difference(-> { UserNameChangeRequest.count }) do
          delete_auth user_name_change_request_path(@change_request), other_user
        end
        assert_response :forbidden
      end

      should "require authentication" do
        assert_no_difference(-> { UserNameChangeRequest.count }) do
          delete user_name_change_request_path(@change_request)
        end
        assert_redirected_to(/session\/new/)
      end
    end
  end
end
