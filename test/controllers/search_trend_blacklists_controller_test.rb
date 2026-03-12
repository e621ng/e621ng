# frozen_string_literal: true

require "test_helper"

class SearchTrendBlacklistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin_user)
  end

  context "index" do
    should "render for admin" do
      get_auth search_trend_blacklists_path, @admin
      assert_response :success
    end

    should "return 403 for non-admin" do
      user = create(:member_user)
      get_auth search_trend_blacklists_path, user
      assert_response 403
    end

    should "return 403 for anonymous" do
      get search_trend_blacklists_path
      assert_response 403
    end
  end

  context "new" do
    should "render for admin" do
      get_auth new_search_trend_blacklist_path, @admin
      assert_response :success
    end

    should "return 403 for non-admin" do
      user = create(:member_user)
      get_auth new_search_trend_blacklist_path, user
      assert_response 403
    end
  end

  context "create" do
    should "create a blacklist entry as admin" do
      assert_difference -> { SearchTrendBlacklist.count }, +1 do
        post_auth search_trend_blacklists_path, @admin, params: {
          search_trend_blacklist: { tag: "wolf", reason: "testing" },
        }
      end
      assert_redirected_to search_trend_blacklists_path
      assert SearchTrendBlacklist.find_by(tag: "wolf")
    end

    should "return 403 for non-admin" do
      user = create(:member_user)
      assert_no_difference -> { SearchTrendBlacklist.count } do
        post_auth search_trend_blacklists_path, user, params: {
          search_trend_blacklist: { tag: "wolf", reason: "" },
        }
      end
      assert_response 403
    end

    should "show errors for invalid input" do
      assert_no_difference -> { SearchTrendBlacklist.count } do
        post_auth search_trend_blacklists_path, @admin, params: {
          search_trend_blacklist: { tag: "", reason: "" },
        }
      end
      assert_response :success
    end
  end

  context "destroy" do
    should "delete a blacklist entry as admin" do
      bl = as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_difference -> { SearchTrendBlacklist.count }, -1 do
        delete_auth search_trend_blacklist_path(bl), @admin
      end
      assert_redirected_to search_trend_blacklists_path
    end

    should "return 403 for non-admin" do
      bl = as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      user = create(:member_user)
      assert_no_difference -> { SearchTrendBlacklist.count } do
        delete_auth search_trend_blacklist_path(bl), user
      end
      assert_response 403
    end
  end
end
