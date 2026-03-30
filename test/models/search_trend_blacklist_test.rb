# frozen_string_literal: true

require "test_helper"

class SearchTrendBlacklistTest < ActiveSupport::TestCase
  setup do
    Setting.trends_enabled = true
    @admin = create(:admin_user)
    Cache.delete(SearchTrendBlacklist::CACHE_KEY)
  end

  teardown do
    Setting.trends_enabled = false
    Cache.delete(SearchTrendBlacklist::CACHE_KEY)
  end

  context "validations" do
    should "require tag presence" do
      bl = SearchTrendBlacklist.new(tag: "", reason: "test")
      assert bl.invalid?
      assert_includes bl.errors[:tag], "can't be blank"
    end

    should "reject duplicate tags (case-insensitive)" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      bl = as @admin do
        SearchTrendBlacklist.new(tag: "Wolf", reason: "")
      end
      assert bl.invalid?
      assert_includes bl.errors[:tag], "already exists"
    end

    should "reject a bare wildcard" do
      bl = SearchTrendBlacklist.new(tag: "*", reason: "test")
      assert bl.invalid?
      assert(bl.errors[:tag].any? { |e| e.include?("bare wildcard") })
    end

    should "allow valid glob patterns" do
      as @admin do
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
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert SearchTrendBlacklist.blacklisted?("wolf")
      assert SearchTrendBlacklist.blacklisted?("WOLF")
      assert_equal false, SearchTrendBlacklist.blacklisted?("fox")
    end

    should "match wildcard patterns" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "*_species", reason: "")
      end
      assert SearchTrendBlacklist.blacklisted?("canine_species")
      assert SearchTrendBlacklist.blacklisted?("feline_species")
      assert_equal false, SearchTrendBlacklist.blacklisted?("wolf")
    end

    should "match single-character wildcard" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "f?x", reason: "")
      end
      assert SearchTrendBlacklist.blacklisted?("fox")
      assert SearchTrendBlacklist.blacklisted?("fax")
      assert_equal false, SearchTrendBlacklist.blacklisted?("wolf")
    end

    should "return false for blank input" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert_equal false, SearchTrendBlacklist.blacklisted?("")
      assert_equal false, SearchTrendBlacklist.blacklisted?(nil)
    end
  end

  context "cached_patterns" do
    should "cache patterns and return them" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      patterns = SearchTrendBlacklist.cached_patterns
      assert_includes patterns, "wolf"
    end

    should "invalidate cache on create" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      # Warm the cache
      SearchTrendBlacklist.cached_patterns
      assert_not_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
      # Create a new entry — should bust cache
      as @admin do
        SearchTrendBlacklist.create!(tag: "fox", reason: "")
      end
      assert_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
    end

    should "invalidate cache on destroy" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      # Warm the cache
      SearchTrendBlacklist.cached_patterns
      assert_not_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
      bl.destroy
      assert_nil Rails.cache.read(SearchTrendBlacklist::CACHE_KEY)
    end
  end

  context "SearchTrend integration" do
    setup do
      Setting.trends_enabled = true
    end

    teardown do
      Setting.trends_enabled = false
    end

    should "bulk_increment! does not skip non-blacklisted tags" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert_difference -> { SearchTrendHourly.count }, +1 do
        SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: 1.hour.ago.utc }])
      end
    end

    should "bulk_increment! skips blacklisted tags" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
        SearchTrendBlacklist.create!(tag: "*_species", reason: "")
      end
      SearchTrendHourly.bulk_increment!([
        { tag: "wolf", hour: 1.hour.ago.utc },
        { tag: "fox", hour: 1.hour.ago.utc },
        { tag: "canine_species", hour: 1.hour.ago.utc },
      ])
      tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
      assert_includes tags, "fox"
      assert_not_includes tags, "wolf"
      assert_not_includes tags, "canine_species"
    end

    should "bulk_increment! skips all tags when all are blacklisted" do
      as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert_no_difference -> { SearchTrendHourly.count } do
        SearchTrendHourly.bulk_increment!([{ tag: "wolf", hour: 1.hour.ago.utc }])
      end
    end
  end

  context "ModAction logging" do
    should "log create" do
      assert_difference -> { ModAction.where(action: "search_trend_blacklist_create").count }, +1 do
        as @admin do
          SearchTrendBlacklist.create!(tag: "wolf", reason: "testing")
        end
      end
    end

    should "log destroy" do
      bl = as @admin do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      assert_difference -> { ModAction.where(action: "search_trend_blacklist_delete").count }, +1 do
        as @admin do
          bl.destroy
        end
      end
    end
  end
end
