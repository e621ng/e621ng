# frozen_string_literal: true

require "test_helper"

class BanTest < ActiveSupport::TestCase
  context "A ban" do
    context "created by an admin" do
      setup do
        @banner = create(:admin_user)
        CurrentUser.user = @banner
      end

      should "set the is_banned flag on the user" do
        user = create(:user)
        ban = build(:ban, user: user, banner: @banner)
        ban.save
        user.reload
        assert(user.is_banned?)
      end

      should "not be valid against another admin" do
        user = create(:admin_user)
        ban = build(:ban, user: user, banner: @banner)
        ban.save
        assert(ban.errors.any?)
      end

      should "be valid against anyone who is not an admin" do
        user = create(:moderator_user)
        ban = create(:ban, user: user, banner: @banner)
        assert(ban.errors.empty?)

        user = create(:privileged_user)
        ban = create(:ban, user: user, banner: @banner)
        assert(ban.errors.empty?)

        user = create(:user)
        ban = create(:ban, user: user, banner: @banner)
        assert(ban.errors.empty?)
      end
    end

    context "created by a moderator" do
      setup do
        @banner = create(:moderator_user)
        CurrentUser.user = @banner
      end

      should "not be valid against an admin or moderator" do
        user = create(:admin_user)
        ban = build(:ban, user: user, banner: @banner)
        ban.save
        assert(ban.errors.any?)

        user = create(:moderator_user)
        ban = build(:ban, user: user, banner: @banner)
        ban.save
        assert(ban.errors.any?)
      end

      should "be valid against anyone who is not an admin or a moderator" do
        user = create(:privileged_user)
        ban = create(:ban, user: user, banner: @banner)
        assert(ban.errors.empty?)

        user = create(:user)
        ban = create(:ban, user: user, banner: @banner)
        assert(ban.errors.empty?)
      end
    end

    should "initialize the expiration date" do
      user = create(:user)
      admin = create(:admin_user)
      as(admin) do
        ban = create(:ban, user: user, banner: admin)
        assert_not_nil(ban.expires_at)
      end
    end

    should "update the user's feedback" do
      user = create(:user)
      admin = create(:admin_user)
      assert(user.feedback.empty?)
      as(admin) do
        create(:ban, user: user, banner: admin)
      end
      assert(!user.feedback.empty?)
      assert_equal("negative", user.feedback.last.category)
    end
  end

  context "Searching for a ban" do
    should "find a given ban" do
      CurrentUser.user = create(:admin_user)

      user = create(:user)
      ban = create(:ban, user: user)
      params = {
        user_name: user.name,
        banner_name: ban.banner.name,
        reason: ban.reason,
        expired: false,
        order: :id_desc
      }

      bans = Ban.search(params)

      assert_equal(1, bans.length)
      assert_equal(ban.id, bans.first.id)
    end

    context "by user id" do
      setup do
        @admin = create(:admin_user)
        CurrentUser.user = @admin
        @user = create(:user)
      end

      context "when only expired bans exist" do
        setup do
          @ban = create(:ban, user: @user, banner: @admin, duration: 1)
        end

        should "not return expired bans" do
          travel_to(2.days.from_now) do
            assert(!Ban.is_banned?(@user))
          end
        end
      end

      context "when active bans still exist" do
        setup do
          @ban = create(:ban, user: @user, banner: @admin, duration: 1)
        end

        should "return active bans" do
          assert(Ban.is_banned?(@user))
        end
      end
    end
  end
end
