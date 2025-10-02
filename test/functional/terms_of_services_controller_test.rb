# frozen_string_literal: true

require "test_helper"

class TermsOfServicesControllerTest < ActionDispatch::IntegrationTest
  context "The terms of services controller" do
    setup do
      @admin = create(:admin_user)
      @original_version = Setting.tos_version.to_i
      as(@admin) do
        create(:wiki_page, title: "e621:terms_of_service", body: "Hello TOS")
      end
      Cache.clear
    end

    teardown do
      Setting.tos_version = @original_version
      Cache.clear
    end

    context "show action" do
      should "render the TOS wiki content" do
        get terms_of_service_path
        assert_response :success
        assert_includes response.body, "Hello TOS"
      end
    end

    context "accept action" do
      should "set a signed cookie when accepted with both checkboxes" do
        Setting.tos_version = 5
        post accept_terms_of_service_path,
             params: { state: "accepted", age: "on", terms: "on" },
             headers: { HTTP_REFERER: root_path }

        assert_redirected_to root_path
        # The Set-Cookie header should include the cookie name
        assert_match(%r{tos_accepted=.*; path=/; expires=}, response.headers["Set-Cookie"].to_s)
      end

      should "not set the cookie and show a notice when declined" do
        post accept_terms_of_service_path,
             params: { state: "declined", age: "on", terms: "on" },
             headers: { HTTP_REFERER: root_path }

        assert_redirected_to root_path
        assert_not_includes(response.headers["Set-Cookie"].to_s, "tos_accepted")
        assert_match(/You must accept the TOS/, flash[:notice])
      end

      should "not set the cookie and show a notice when checkboxes are missing" do
        post accept_terms_of_service_path,
             params: { state: "accepted", age: "on" },
             headers: { HTTP_REFERER: root_path }

        assert_redirected_to root_path
        assert_not_includes(response.headers["Set-Cookie"].to_s, "tos_accepted")
        assert_match(/You must accept the TOS/, flash[:notice])
      end
    end

    context "clear_cache action" do
      should "require login for anonymous users" do
        post clear_cache_terms_of_service_path
        assert_redirected_to new_session_path
      end

      should "require admin and clear the cached content" do
        Cache.expects(:delete).with("tos_content")
        post_auth clear_cache_terms_of_service_path, @admin
        assert_redirected_to terms_of_service_path
        assert_equal "Terms of service cache cleared", flash[:notice]
      end
    end

    context "bump_version action" do
      should "require login for anonymous users" do
        post bump_version_terms_of_service_path
        assert_redirected_to new_session_path
      end

      should "increment the version, clear cache, and redirect for admins" do
        Setting.tos_version = 10
        Cache.expects(:delete).with("tos_content")

        post_auth bump_version_terms_of_service_path, @admin

        assert_redirected_to terms_of_service_path
        assert_equal 11, Setting.tos_version.to_i
        assert_equal "Terms of service version bumped to 11", flash[:notice]
      end
    end
  end
end
