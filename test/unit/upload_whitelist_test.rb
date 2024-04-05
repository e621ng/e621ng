# frozen_string_literal: true

require "test_helper"

class UploadWhitelistTest < ActiveSupport::TestCase
  context "A upload whitelist" do
    setup do
      user = create(:privileged_user)
      CurrentUser.user = user

      @whitelist = create(:upload_whitelist, pattern: "*.e621.net/data/*", note: "e621")
    end

    should "match" do
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://static1.e621.net/data/123.png")))
      assert_equal([false, "123.com not in whitelist"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png")))
    end

    should "bypass for admins" do
      CurrentUser.user.level = 50
      Danbooru.config.stubs(:bypass_upload_whitelist?).returns(true)
      assert_equal([true, "bypassed"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png")))
    end
  end
end
