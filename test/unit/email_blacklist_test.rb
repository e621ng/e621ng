require 'test_helper'

class EmailBlacklistTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    CurrentUser.user = FactoryBot.create(:mod_user)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  teardown do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  should "detect email by suffix" do
    block = EmailBlacklist.create(creator: @user, domain: '.xyz', reason: 'test')

    assert(EmailBlacklist.is_banned?('spam@what.xyz'))
    assert_equal(false, EmailBlacklist.is_banned?('good@angelic.com'))
  end

  should "detect email by mx" do
    block = EmailBlacklist.create(creator: @user, domain: 'google.com', reason: 'test')

    assert(EmailBlacklist.is_banned?('spam@e621.net'))
    assert_equal(false, EmailBlacklist.is_banned?('what@me.xynzs'))
  end
end
