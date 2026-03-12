# frozen_string_literal: true

require "test_helper"

class SearchTrendBlacklistTest < ActiveSupport::TestCase
  setup do
    @admin = create(:admin_user)
    Cache.delete(SearchTrendBlacklist::CACHE_KEY)
  end

  teardown do
    Cache.delete(SearchTrendBlacklist::CACHE_KEY)
  end

  context "validations" do
    should "require tag presence" do
      bl = SearchTrendBlacklist.new(tag: "", reason: "test")
      assert bl.invalid?
      assert_includes bl.errors[:tag], "can't be blank"
    end

    should "reject duplicate tags (case-insensitive)" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      bl = as_user(@admin) { SearchTrendBlacklist.new(tag: "Wolf", reason: "") }
      assert bl.invalid?
      assert_includes bl.errors[:tag], "already exists"
    end

    should "reject a bare wildcard" do
      bl = SearchTrendBlacklist.new(tag: "*", reason: "test")
      assert bl.invalid?
      assert bl.errors[:tag].any? { |e| e.include?("bare wildcard") }
    end

    should "allow valid glob patterns" do
      as_user(@admin) do
        bl = SearchTrendBlacklist.new(tag: "*_species", reason: "test")
        assert bl.valid?
      end
    end
  end

  context "blacklisted?" do
    should "return false when list is empty" do
      assert_equal false, SearchTrendBlacklist.blacklisted?("wolf")
    end

    should "match exact tags" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert SearchTrendBlacklist.blacklisted?("wolf")
      assert SearchTrendBlacklist.blacklisted?("WOLF")
      assert_equal false, SearchTrendBlacklist.blacklisted?("fox")
    end

    should "match wildcard patterns" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "*_species", reason: "") }
      assert SearchTrendBlacklist.blacklisted?("canine_species")
      assert SearchTrendBlacklist.blacklisted?("feline_species")
      assert_equal false, SearchTrendBlacklist.blacklisted?("wolf")
    end

    should "match single-character wildcard" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "f?x", reason: "") }
      assert SearchTrendBlacklist.blacklisted?("fox")
      assert SearchTrendBlacklist.blacklisted?("fax")
      assert_equal false, SearchTrendBlacklist.blacklisted?("wolf")
    end

    should "return false for blank input" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_equal false, SearchTrendBlacklist.blacklisted?("")
      assert_equal false, SearchTrendBlacklist.blacklisted?(nil)
    end
  end

  context "cached_patterns" do
    should "cache patterns and return them" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      patterns = SearchTrendBlacklist.cached_patterns
      assert_includes patterns, "wolf"
    end

    should "invalidate cache on create" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      # Warm the cache
      SearchTrendBlacklist.cached_patterns
      assert_not_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
      # Create a new entry — should bust cache
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "fox", reason: "") }
      assert_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
    end

    should "invalidate cache on destroy" do
      bl = as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      # Warm the cache
      SearchTrendBlacklist.cached_patterns
      assert_not_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
      bl.destroy
      assert_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
    end
  end

  context "SearchTrend integration" do
    should "increment! skips blacklisted tags" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_no_difference -> { SearchTrend.count } do
        SearchTrend.increment!("wolf")
      end
    end

    should "increment! does not skip non-blacklisted tags" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_difference -> { SearchTrend.count }, +1 do
        SearchTrend.increment!("fox")
      end
    end

    should "bulk_increment! skips blacklisted tags" do
      as_user(@admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
        SearchTrendBlacklist.create!(tag: "*_species", reason: "")
      end
      SearchTrend.bulk_increment!(%w[wolf fox canine_species])
      tags = SearchTrend.for_day(Date.current).pluck(:tag)
      assert_includes tags, "fox"
      assert_not_includes tags, "wolf"
      assert_not_includes tags, "canine_species"
    end

    should "bulk_increment! skips all tags when all are blacklisted" do
      as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_no_difference -> { SearchTrend.count } do
        SearchTrend.bulk_increment!(%w[wolf])
      end
    end
  end

  context "ModAction logging" do
    should "log create" do
      assert_difference -> { ModAction.where(action: "search_trend_blacklist_create").count }, +1 do
        as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "testing") }
      end
    end

    should "log destroy" do
      bl = as_user(@admin) { SearchTrendBlacklist.create!(tag: "wolf", reason: "") }
      assert_difference -> { ModAction.where(action: "search_trend_blacklist_delete").count }, +1 do
        bl.destroy
      end
    end
  end
end
