# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  context "the sessions controller" do
    context "new action" do
      should "render" do
        get new_session_path
        assert_response :success
      end
    end

    context "create action" do
      should "create a new session" do
        user = create(:user)

        post session_path, params: { session: { name: user.name, password: "6cQE!wbA" } }
        user.reload

        assert_redirected_to(posts_path)
        assert_not_nil(user.last_ip_addr)
        assert_equal(user.id, session[:user_id])
      end

      should "not update last_ip_addr for banned accounts" do
        user = create(:banned_user)

        get_auth posts_path, user, params: { format: :json }
        user.reload

        assert_nil(user.last_ip_addr)
      end

      should "fail when provided an invalid password" do
        user = create(:user, password: "6cQE!wbA", password_confirmation: "6cQE!wbA")
        post session_path, params: { session: { name: user.name, password: "yyy" } }

        assert_nil(session[:user_id])
        assert_equal("Username/Password was incorrect", flash[:notice])
      end
    end

    context "destroy action" do
      should "clear the session" do
        user = create(:user)

        post session_path, params: { session: { name: user.name, password: "6cQE!wbA" } }
        assert_not_nil(session[:user_id])

        delete_auth(session_path, user)
        assert_redirected_to(posts_path)
        assert_nil(session[:user_id])
      end
    end
  end
end
