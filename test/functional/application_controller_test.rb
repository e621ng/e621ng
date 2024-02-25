# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  context "The application controller" do
    should "return 406 Not Acceptable for a bad file extension" do
      get posts_path, params: { format: :jpg }
      assert_response 406

      get posts_path, params: { format: :blah }
      assert_response 406

      get post_path("bad.json")
      assert_response 404

      get post_path("bad.jpg")
      assert_response 406

      get post_path("bad.blah")
      assert_response 406
    end

    context "on a PaginationError" do
      should "return 410 Gone even with a bad file extension" do
        get posts_path, params: { page: 999999999 }, as: :json
        assert_response 410

        get posts_path, params: { page: 999999999 }, as: :jpg
        assert_response 410

        get posts_path, params: { page: 999999999 }, as: :blah
        assert_response 410
      end
    end

    context "on api authentication" do
      setup do
        @user = create(:user, password: "password")
        @api_key = ApiKey.generate!(@user)

        ActionController::Base.allow_forgery_protection = true
      end

      teardown do
        ActionController::Base.allow_forgery_protection = false
      end

      context "using http basic auth" do
        should "succeed for api key matches" do
          basic_auth_string = "Basic #{::Base64.encode64("#{@user.name}:#{@api_key.key}")}"
          get edit_user_path(@user), headers: { HTTP_AUTHORIZATION: basic_auth_string }
          assert_response :success
        end

        should "fail for api key mismatches" do
          basic_auth_string = "Basic #{::Base64.encode64("#{@user.name}:badpassword")}"
          get edit_user_path(@user), headers: { HTTP_AUTHORIZATION: basic_auth_string }
          assert_response 401
        end

        should "succeed for non-GET requests without a CSRF token" do
          assert_changes -> { @user.reload.enable_safe_mode }, from: false, to: true do
            basic_auth_string = "Basic #{::Base64.encode64("#{@user.name}:#{@api_key.key}")}"
            put user_path(@user), headers: { HTTP_AUTHORIZATION: basic_auth_string }, params: { user: { enable_safe_mode: "true" } }, as: :json
            assert_response :success
          end
        end
      end

      context "using the api_key parameter" do
        should "succeed for api key matches" do
          get edit_user_path(@user), params: { login: @user.name, api_key: @api_key.key }
          assert_response :success
        end

        should "fail for api key mismatches" do
          get edit_user_path(@user), params: { login: @user.name }
          assert_response 401

          get edit_user_path(@user), params: { api_key: @api_key.key }
          assert_response 401

          get edit_user_path(@user), params: { login: @user.name, api_key: "bad" }
          assert_response 401
        end

        should "succeed for non-GET requests without a CSRF token" do
          assert_changes -> { @user.reload.enable_safe_mode }, from: false, to: true do
            put user_path(@user), params: { login: @user.name, api_key: @api_key.key, user: { enable_safe_mode: "true" } }, as: :json
            assert_response :success
          end
        end
      end

      context "without any authentication" do
        should "redirect to the login page" do
          get edit_user_path(@user)
          assert_redirected_to new_session_path(url: edit_user_path(@user))
        end
      end

      context "with cookie-based authentication" do
        should "not allow non-GET requests without a CSRF token" do
          # get the csrf token from the login page so we can login
          get new_session_path
          assert_response :success
          token = css_select("form input[name=authenticity_token]").first["value"]

          # login
          post session_path, params: { authenticity_token: token, name: @user.name, password: "password" }
          assert_redirected_to posts_path

          # try to submit a form with cookies but without the csrf token
          put user_path(@user), headers: { HTTP_COOKIE: headers["Set-Cookie"] }, params: { user: { enable_safe_mode: "true" } }
          assert_response 403
          assert_match(/ActionController::InvalidAuthenticityToken/, css_select("p").first.content)
          assert_equal(false, @user.reload.enable_safe_mode)
        end
      end
    end

    context "on session cookie authentication" do
      should "succeed" do
        user = create(:user, password: "password")

        post session_path, params: { name: user.name, password: "password" }
        get edit_user_path(user)

        assert_response :success
      end
    end

    context "when the api limit is exceeded" do
      should "fail with a 429 error" do
        user = create(:user)
        post = create(:post, rating: "s", uploader: user)
        UserThrottle.any_instance.stubs(:throttled?).returns(true)

        put_auth post_path(post), user, params: { post: { rating: "e" } }

        assert_response 429
        assert_equal("s", post.reload.rating)
      end
    end
  end
end
