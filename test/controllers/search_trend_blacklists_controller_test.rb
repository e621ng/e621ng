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

    should "redirect to login page" do
      get search_trend_blacklists_path
      assert_response 302
      assert_includes response.location, "/session/new"
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

  context "edit" do
    should "render for admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      get_auth edit_search_trend_blacklist_path(bl), @admin
      assert_response :success
    end

    should "return 403 for non-admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      user = create(:member_user)
      get_auth edit_search_trend_blacklist_path(bl), user
      assert_response 403
    end
  end

  context "update" do
    should "update a blacklist entry as admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "old reason")
      end
      put_auth search_trend_blacklist_path(bl), @admin, params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      assert_redirected_to search_trend_blacklists_path
      assert_equal "new reason", bl.reload.reason
    end

    should "return 403 for non-admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "old reason")
      end
      user = create(:member_user)
      put_auth search_trend_blacklist_path(bl), user, params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      assert_response 403
      assert_equal "old reason", bl.reload.reason
    end

    should "show errors for invalid input" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      put_auth search_trend_blacklist_path(bl), @admin, params: {
        search_trend_blacklist: { tag: "" },
      }
      assert_response :success
      assert_equal "wolf", bl.reload.tag
    end
  end

  context "destroy" do
    should "delete a blacklist entry as admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert_difference -> { SearchTrendBlacklist.count }, -1 do
        delete_auth search_trend_blacklist_path(bl), @admin
      end
      assert_redirected_to search_trend_blacklists_path
    end

    should "return 403 for non-admin" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      user = create(:member_user)
      assert_no_difference -> { SearchTrendBlacklist.count } do
        delete_auth search_trend_blacklist_path(bl), user
      end
      assert_response 403
    end
  end
end
