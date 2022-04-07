require 'test_helper'

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
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
      CurrentUser.safe_mode = nil
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
        @request.stubs(:session).returns(user_id: @user.id)
        SessionLoader.new(@request).load

        assert_equal(true, CurrentUser.safe_mode?)
      end
    end
  end
end
