# frozen_string_literal: true

require "test_helper"

module Moderator
  class IpAddrSearchTest < ActiveSupport::TestCase
    context "an ip addr search" do
      setup do
        @user = create(:user)
        CurrentUser.user = @user
        CurrentUser.ip_addr = "170.1.2.3"
        create(:comment, creator: @user, creator_ip_addr: CurrentUser.ip_addr)
      end

      should "find by ip addr" do
        @result = IpAddrSearch.new(ip_addr: "170.1.2.3").execute
        assert_equal(@result[:users][@user.id].id, @user.id)
        assert_equal(@result[:sums][:comment][@user.id], 1)
      end

      should "find by user id" do
        @result = IpAddrSearch.new(user_id: @user.id.to_s).execute
        assert_equal(@result[:sums][:comment][IPAddr.new("170.1.2.3")], 1)
      end

      should "find by user name" do
        @result = IpAddrSearch.new(user_name: @user.name).execute
        assert_equal(@result[:sums][:comment][IPAddr.new("170.1.2.3")], 1)
      end
    end
  end
end
