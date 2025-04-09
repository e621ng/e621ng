# frozen_string_literal: true

require "test_helper"

class ElasticPostQueryBuilderTest < ActiveSupport::TestCase
  DEFAULT_PARAM = { resolve_aliases: true, free_tags_count: 0, enable_safe_mode: false, always_show_deleted: false }.freeze
  # TODO: Add tests for proper construction
  context "While building a post query" do
    should "properly determine whether or not to hide deleted posts" do
      assert(ElasticPostQueryBuilder.new("aaa bbb", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa bbb status:deleted", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa bbb deletedby:someone", **DEFAULT_PARAM).hide_deleted_posts?)
      # Don't overwrite
      assert_not(ElasticPostQueryBuilder.new("aaa bbb delreason:something status:pending", **DEFAULT_PARAM).hide_deleted_posts?)
      assert(ElasticPostQueryBuilder.new("( aaa bbb )", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb status:any )", **DEFAULT_PARAM).hide_deleted_posts?)
      assert(ElasticPostQueryBuilder.new("( aaa ( bbb ) )", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa status:any ) )", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa deletedby:someone ) )", **DEFAULT_PARAM).hide_deleted_posts?)
      assert_not(ElasticPostQueryBuilder.new("aaa ( bbb ( aaa delreason:something ) status:pending )", **DEFAULT_PARAM).hide_deleted_posts?)
    end
  end

  should "handle filtering correctly" do
    cb = ->(x) {
      x&.dig(:bool, :must)&.any? do |e|
        e == { term: { deleted: false } } || (e.is_a?(Array) & cb.call(e))
      end
    }
    qb = ElasticPostQueryBuilder.new("aaa bbb", **DEFAULT_PARAM).create_query_obj
    assert_includes(qb.dig(:bool, :must), { term: { deleted: false } })
    qb = ElasticPostQueryBuilder.new("aaa bbb status:deleted", **DEFAULT_PARAM).create_query_obj
    assert_not(cb.call(qb))
    qb = ElasticPostQueryBuilder.new("aaa bbb deletedby:someone", **DEFAULT_PARAM).create_query_obj
    assert_not(cb.call(qb))
    # In prior versions, deleted filtering was based of the final value of `status`/`status_must_not`, so the metatag ordering changed the results. This ensures this legacy behavior stays gone.
    qb = ElasticPostQueryBuilder.new("aaa bbb delreason:something status:pending", **DEFAULT_PARAM).create_query_obj
    assert_not(cb.call(qb))
    qb = ElasticPostQueryBuilder.new("( aaa bbb )", **DEFAULT_PARAM).create_query_obj
    assert(cb.call(qb))
    qb = ElasticPostQueryBuilder.new("( aaa ( bbb ) )", **DEFAULT_PARAM).create_query_obj
    assert(cb.call(qb))
    [true, false].each do |e|
      msg = -"process_groups: #{e}"
      qb = ElasticPostQueryBuilder.new("aaa ( bbb status:any )", process_groups: e, **DEFAULT_PARAM).create_query_obj
      assert_not(cb.call(qb), msg)
      qb = ElasticPostQueryBuilder.new("aaa ( bbb ( aaa status:any ) )", process_groups: e, **DEFAULT_PARAM).create_query_obj
      assert_not(cb.call(qb), msg)
      qb = ElasticPostQueryBuilder.new("aaa ( bbb ( aaa deletedby:someone ) )", process_groups: e, **DEFAULT_PARAM).create_query_obj
      assert_not(cb.call(qb), msg)
      qb = ElasticPostQueryBuilder.new("aaa ( bbb ( aaa delreason:something ) status:pending )", process_groups: e, **DEFAULT_PARAM).create_query_obj
      assert_not(cb.call(qb), msg)
    end
  end
end
