# frozen_string_literal: true

require "test_helper"

class ElasticPostQueryBuilderTest < ActiveSupport::TestCase
  # TODO: Add tests for proper construction
  context "While building a post query" do
    should "properly determine whether or not to hide deleted posts" do
      p = { resolve_aliases: true, free_tags_count: 0, enable_safe_mode: false, always_show_deleted: false }
      assert(ElasticPostQueryBuilder.new("aaa bbb", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa bbb status:deleted", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa bbb deletedby:someone", **p).hide_deleted_posts?)
      # Don't overwrite
      assert_not(ElasticPostQueryBuilder.new("aaa bbb delreason:something status:pending", **p).hide_deleted_posts?)
      assert(ElasticPostQueryBuilder.new("( aaa bbb )", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb status:any )", **p).hide_deleted_posts?)
      assert(ElasticPostQueryBuilder.new("( aaa ( bbb ) )", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa status:any ) )", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa deletedby:someone ) )", **p).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa delreason:something ) status:pending )", **p).hide_deleted_posts?)
    end
  end
end
