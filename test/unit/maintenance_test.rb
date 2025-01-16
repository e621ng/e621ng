# frozen_string_literal: true

require "test_helper"

class MaintenanceTest < ActiveSupport::TestCase
  context "daily maintenance" do
    should "work" do
      assert_nothing_raised { Maintenance.daily }
    end

    context "when pruning bans" do
      should "clear the is_banned flag for users who are no longer banned" do
        banner = create(:admin_user)
        user = create(:user)

        as(banner) { create(:ban, user: user, banner: banner, duration: 1) }

        assert_equal(true, user.reload.is_banned)
        travel_to(2.days.from_now) { Maintenance.daily }
        assert_equal(false, user.reload.is_banned)
      end
    end
  end
end
