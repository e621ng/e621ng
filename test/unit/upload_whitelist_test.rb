# frozen_string_literal: true

require "test_helper"

class UploadWhitelistTest < ActiveSupport::TestCase
  context "A upload whitelist" do
    setup do
      user = create(:privileged_user)
      CurrentUser.user = user

      # domain regex matches any subdomain of e621.net
      # path regex matches /data/ followed by anything
      @whitelist = create(:upload_whitelist,
                          domain: "static1\.e621\.net", # rubocop:disable Style/RedundantStringEscape
                          path: "\/data\/.*", # rubocop:disable Style/RedundantStringEscape
                          allowed: true,
                          reason: nil,
                          note: "e621")
    end

    should "succeed for valid URLs" do
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?("https://static1.e621.net/data/123.png"))
    end

    should "fail for invalid URLs" do
      assert_equal([false, "invalid url"], UploadWhitelist.is_whitelisted?(""))
      assert_equal([false, "invalid url"], UploadWhitelist.is_whitelisted?(nil))
      assert_equal([false, "123.com not in whitelist"], UploadWhitelist.is_whitelisted?("https://123.com/what.png"))
      assert_equal([false, "aaa not in whitelist"], UploadWhitelist.is_whitelisted?("aaa"))
      assert_equal([false, "example.com not in whitelist"], UploadWhitelist.is_whitelisted?("https://example.com/test?=https://static1.e621.net/data/123.jpeg"))
    end

    should "bypass for admins" do
      CurrentUser.user.level = 50
      Danbooru.config.stubs(:bypass_upload_whitelist?).returns(true)
      assert_equal([true, "bypassed"], UploadWhitelist.is_whitelisted?("https://123.com/what.png"))
    end
  end
end
