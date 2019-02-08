require 'test_helper'

class UploadWhitelistTest < ActiveSupport::TestCase
  context "A upload whitelist" do
    setup do
      user = FactoryBot.create(:contributor_user)
      CurrentUser.user = user
      CurrentUser.ip_addr = "127.0.0.1"

      @whitelist = FactoryBot.create(:upload_whitelist, pattern: "*.e621.net/data/*", note: "e621")
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end
    should "match" do
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?("https://static1.e621.net/data/123.png"))
      assert_equal([false, "not found"], UploadWhitelist.is_whitelisted?("https://123.com/what.png"))
    end

    should "bypass for admins" do
      CurrentUser.user.level = 50
      Danbooru.config.stubs(:bypass_upload_whitelist?).returns(true)
      assert_equal([true, "bypassed"], UploadWhitelist.is_whitelisted?("https://123.com/what.png"))
    end
  end
end
