# frozen_string_literal: true

require "test_helper"

class SessionLoaderTest < ActiveSupport::TestCase
  context "SessionLoader" do
    setup do
      @request = mock
      @request.stubs(:host).returns("danbooru")
      @request.stubs(:remote_ip).returns("127.0.0.1")
      @request.stubs(:authorization).returns(nil)
      cookie_jar = mock
      cookie_jar.stubs(:encrypted).returns({})
      @request.stubs(:cookie_jar).returns(cookie_jar)
      @request.stubs(:parameters).returns({})
      @request.stubs(:session).returns({})

      SessionLoader.any_instance.stubs(:skip_cookies?).returns(true)
    end

    context ".safe_mode?" do
      should "return true if the config has safe mode enabled" do
        Danbooru.config.stubs(:safe_mode?).returns(true)
        SessionLoader.new(@request).load

        assert_equal(true, CurrentUser.safe_mode?)
      end

      should "return false if the config has safe mode disabled" do
        Danbooru.config.stubs(:safe_mode?).returns(false)
        SessionLoader.new(@request).load

        assert_equal(false, CurrentUser.safe_mode?)
      end

      should "return true if the user has enabled the safe mode account setting" do
        @user = create(:user, enable_safe_mode: true)
        @request.stubs(:session).returns(user_id: @user.id, ph: @user.password_token)
        SessionLoader.new(@request).load

        assert_equal(true, CurrentUser.safe_mode?)
      end
    end

    context "authentication with invalid UTF-8" do
      should "reject Basic Auth with invalid UTF-8 bytes" do
        # Create invalid UTF-8 sequence and encode it
        invalid_utf8 = String.new("\xee\xce\x0d", encoding: "ASCII-8BIT")
        auth_header = "Basic #{::Base64.strict_encode64(invalid_utf8)}"
        @request.stubs(:authorization).returns(auth_header)

        assert_raises(SessionLoader::AuthenticationFailure) do
          SessionLoader.new(@request).load
        end
      end

      should "reject login parameter with invalid UTF-8" do
        invalid_login = String.new("user\xee\xce\x0d", encoding: "ASCII-8BIT")
        @request.stubs(:parameters).returns({ login: invalid_login, api_key: "test_key" })

        assert_raises(SessionLoader::AuthenticationFailure) do
          SessionLoader.new(@request).load
        end
      end

      should "reject api_key parameter with invalid UTF-8" do
        invalid_key = String.new("key\xee\xce\x0d", encoding: "ASCII-8BIT")
        @request.stubs(:parameters).returns({ login: "testuser", api_key: invalid_key })

        assert_raises(SessionLoader::AuthenticationFailure) do
          SessionLoader.new(@request).load
        end
      end

      should "reject malformed Base64 in Basic Auth" do
        @request.stubs(:authorization).returns("Basic not-valid-base64!@#$%")

        assert_raises(SessionLoader::AuthenticationFailure) do
          SessionLoader.new(@request).load
        end
      end
    end
  end
end
