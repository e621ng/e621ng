require 'test_helper'

class EmailBlacklistTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    CurrentUser.user = create(:mod_user)
  end

  should "detect email by suffix" do
    block = EmailBlacklist.create(creator: @user, domain: '.xyz', reason: 'test')

    assert(EmailBlacklist.is_banned?('spam@what.xyz'))
    assert_equal(false, EmailBlacklist.is_banned?('good@angelic.com'))
  end

  should "detect email by mx" do
    block = EmailBlacklist.create(creator: @user, domain: 'google.com', reason: 'test')
    EmailBlacklist.stubs(:get_mx_records).returns(['google.com'])
    assert(EmailBlacklist.is_banned?('spam@e621.net'))

    EmailBlacklist.unstub(:get_mx_records)
    assert_equal(false, EmailBlacklist.is_banned?('what@me.xynzs'))
  end

  should "keep accounts verified if there are too many matches" do
    stub_const(EmailBlacklist, :UNVERIFY_COUNT_TRESHOLD, 5) do
      users = create_list(:user, EmailBlacklist::UNVERIFY_COUNT_TRESHOLD + 1) do |user, i|
        user.email = "#{i}@domain.com"
      end
      EmailBlacklist.create(creator: @user, domain: "domain.com", reason: "test")
      users.each(&:reload)
      assert users.all?(&:is_verified?)
    end
  end

  should "unverify accounts if there are few matches" do
    @domain_blocked_user = create(:user, email: "0@domain.com")
    @other_user1 = create(:user, email: "0@prefix.domain.com")
    @other_user2 = create(:user, email: "0@somethingelse.xynzs")
    EmailBlacklist.create(creator: @user, domain: "domain.com", reason: "test")
    @domain_blocked_user.reload
    @other_user1.reload
    @other_user2.reload
    assert_not @domain_blocked_user.is_verified?
    assert @other_user1.is_verified?
    assert @other_user2.is_verified?
  end
end
