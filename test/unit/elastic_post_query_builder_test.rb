# frozen_string_literal: true

require "test_helper"

class ElasticPostQueryBuilderTest < ActiveSupport::TestCase
  DEFAULT_PARAM = { resolve_aliases: true, free_tags_count: 0, enable_safe_mode: false, always_show_deleted: false }.freeze
  def has_term_with_at?(x, value, **kwargs) # rubocop:disable Naming/MethodParameterName
    kwargs = { path: :must, field: :deleted, term: nil, depth: 0 }.merge(kwargs)
    kwargs[:term] ||= { term: { kwargs[:field] => value } }
    out = kwargs[:depth]
    if x&.dig(:bool, kwargs[:path])&.any? do |e|
         kwargs[:term] === e || (e.is_a?(Array) && (out = has_term_with_at?(e, value, **kwargs, depth: kwargs[:depth] + 1))) # rubocop:disable Style/CaseEquality
       end
      out.is_a?(Numeric) ? out : kwargs[:depth]
    else
      false
    end
  end

  def has_term_with?(x, value, path: :must, field: :deleted, term: nil) # rubocop:disable Naming/MethodParameterName
    term ||= { term: { field => value } }
    x&.dig(:bool, path)&.any? do |e|
      term === e || (e.is_a?(Array) && has_term_with?(e, value, path: path, field: field, term: term)) # rubocop:disable Style/CaseEquality
    end
  end

  def has_deleted_with?(x, value = nil, path = :must, invert: true) # rubocop:disable Naming/MethodParameterName
    term = case value
           when true, false then { term: { deleted: value } }
           else
             ->(e) { [{ term: { deleted: false } }, { term: { deleted: true } }].include?(e) }
           end
    if path.nil?
      has_term_with?(x, nil, path: :must, term: term) || has_term_with?(x, nil, path: :must_not, term: term)
    elsif path.is_a?(Array)
      path.any? { |p| has_term_with?(x, nil, path: p, term: term) }
    elsif invert
      if path == :must
        has_term_with?(x, nil, path: :must, term: term) || has_term_with?(x, nil, path: :must_not, term: { term: { deleted: !value } })
      else # if path == :must_not
        has_term_with?(x, nil, path: :must_not, term: term) || has_term_with?(x, nil, path: :must, term: { term: { deleted: !value } })
      end
    else
      has_term_with?(x, nil, path: path, term: term)
    end
  end

  def build_query(query, **)
    ElasticPostQueryBuilder.new(query, **DEFAULT_PARAM, **)
  end

  def build_query_obj(query, **)
    ElasticPostQueryBuilder.new(query, **DEFAULT_PARAM, **).create_query_obj
  end

  def normalize(obj)
    obj.dig(:function_score, :query) || obj
  end

  def get_root(obj)
    normalize(obj).fetch(:bool, obj)
  end

  # TODO: Add tests for proper construction
  context "While building a post query" do
    should "properly determine whether or not to hide deleted posts" do
      assert(build_query("aaa bbb").hide_deleted_posts?)
      assert_not(build_query("aaa bbb status:deleted").hide_deleted_posts?)
      assert_not(build_query("aaa bbb deletedby:someone").hide_deleted_posts?)
      # Don't overwrite
      assert_not(build_query("aaa bbb delreason:something status:pending").hide_deleted_posts?)
      assert(build_query("( aaa bbb )").hide_deleted_posts?)
      assert_not(build_query("aaa ( bbb status:any )").hide_deleted_posts?)
      assert(build_query("( aaa ( bbb ) )").hide_deleted_posts?)
      assert_not(build_query("aaa ( bbb ( aaa status:any ) )").hide_deleted_posts?)
      assert_not(build_query("aaa ( bbb ( aaa deletedby:someone ) )").hide_deleted_posts?)
      assert_not(build_query("aaa ( bbb ( aaa delreason:something ) status:pending )").hide_deleted_posts?)
    end
  end

  # TODO: Test `ElasticPostQueryBuilder::GLOBAL_DELETED_FILTER`
  should "handle filtering correctly" do
    qb = build_query_obj(query = "aaa bbb")
    assert(has_deleted_with?(qb, false))
    assert_not(has_deleted_with?(qb, true))
    non_override = (TagQuery::STATUS_VALUES - TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES).freeze

    # status:deleted
    qb = build_query_obj(query = "aaa bbb status:deleted")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    assert(has_deleted_with?(qb, true), "#{query} #{qb}")
    qb = build_query_obj(query = "aaa bbb -status:deleted")
    assert(has_deleted_with?(normalize(qb), true, :must_not), "#{query} #{qb}")
    assert_not(has_deleted_with?(normalize(qb), true), "#{query} #{qb}")
    non_override.each do |y|
      qb = build_query_obj(query = -"aaa bbb status:deleted status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:deleted status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb status:deleted -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:deleted -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
    end

    # status:active
    qb = build_query_obj(query = "aaa bbb status:active")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    assert_not(has_deleted_with?(qb, true), "#{query} #{qb}")
    qb = build_query_obj(query = "aaa bbb -status:active")
    assert(qb.dig(:bool, :must, 0, :bool, :should)&.any? { |e| e == { term: { deleted: true } } }, "#{query} #{qb}")
    assert_not(has_deleted_with?(qb, false, %i[must_not should]), "#{query} #{qb}")
    non_override.each do |y|
      qb = build_query_obj(query = -"aaa bbb status:active status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:active status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb status:active -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:active -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
    end
    # Every value that doesn't explicitly set a value for deleted posts (e.g. `any` & `all`)
    (TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES - %w[active deleted]).each do |x|
      qb = build_query_obj(query = -"aaa bbb status:#{x}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:#{x}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      non_override.each do |y|
        qb = build_query_obj(query = -"aaa bbb status:#{x} status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb -status:#{x} status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb status:#{x} -status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb -status:#{x} -status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      end
    end
    qb = build_query_obj(query = "aaa bbb deletedby:someone")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    # In prior versions, deleted filtering was based of the final value of `status`/`status_must_not`, so the metatag ordering changed the results. This ensures this legacy behavior stays gone.
    qb = build_query_obj(query = "aaa bbb delreason:something status:pending")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    qb = build_query_obj(query = "( aaa bbb )")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    qb = build_query_obj(query = "( aaa ( bbb ) )")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    [true, false].each do |e|
      msg = -"process_groups: #{e}"
      qb = build_query_obj(query = "aaa ( bbb status:any )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa status:any ) )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa deletedby:someone ) )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa delreason:something ) status:pending )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
    end
    # assert_includes(ElasticPostQueryBuilder.new("status:pending", resolve_aliases: true, free_tags_count: 0, enable_safe_mode: false, always_show_deleted: false).create_query_obj, { term: { pending: true } })
  end

  should_eventually "correctly parse status values" do
    # TODO: convert to test output not filtering
    qb = build_query_obj(query = "aaa bbb")
    assert(has_deleted_with?(qb, false))
    assert_not(has_deleted_with?(qb, true))
    non_override = (TagQuery::STATUS_VALUES - TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES).freeze

    # status:deleted
    qb = build_query_obj(query = "aaa bbb status:deleted")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    assert(has_deleted_with?(qb, true), "#{query} #{qb}")
    qb = build_query_obj(query = "aaa bbb -status:deleted")
    assert(has_deleted_with?(normalize(qb), true, :must_not), "#{query} #{qb}")
    assert_not(has_deleted_with?(normalize(qb), true), "#{query} #{qb}")
    non_override.each do |y|
      qb = build_query_obj(query = -"aaa bbb status:deleted status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:deleted status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb status:deleted -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:deleted -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      assert_not(has_deleted_with?(qb, :must_not), "#{query} #{qb}")
    end

    # status:active
    qb = build_query_obj(query = "aaa bbb status:active")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    assert_not(has_deleted_with?(qb, true), "#{query} #{qb}")
    qb = build_query_obj(query = "aaa bbb -status:active")
    assert(qb.dig(:bool, :must, 0, :bool, :should)&.any? { |e| e == { term: { deleted: true } } }, "#{query} #{qb}")
    assert_not(has_deleted_with?(qb, false, %i[must_not should]), "#{query} #{qb}")
    non_override.each do |y|
      qb = build_query_obj(query = -"aaa bbb status:active status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:active status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb status:active -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:active -status:#{y}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
    end
    # Every value that doesn't explicitly set a value for deleted posts (e.g. `any` & `all`)
    (TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES - %w[active deleted]).each do |x|
      qb = build_query_obj(query = -"aaa bbb status:#{x}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      qb = build_query_obj(query = -"aaa bbb -status:#{x}")
      assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      non_override.each do |y|
        qb = build_query_obj(query = -"aaa bbb status:#{x} status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb -status:#{x} status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb status:#{x} -status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
        qb = build_query_obj(query = -"aaa bbb -status:#{x} -status:#{y}")
        assert_not(has_deleted_with?(qb), "#{query} #{qb}")
      end
    end
    qb = build_query_obj(query = "aaa bbb deletedby:someone")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    # In prior versions, deleted filtering was based of the final value of `status`/`status_must_not`, so the metatag ordering changed the results. This ensures this legacy behavior stays gone.
    qb = build_query_obj(query = "aaa bbb delreason:something status:pending")
    assert_not(has_deleted_with?(qb, false), "#{query} #{qb}")
    qb = build_query_obj(query = "( aaa bbb )")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    qb = build_query_obj(query = "( aaa ( bbb ) )")
    assert(has_deleted_with?(qb, false), "#{query} #{qb}")
    [true, false].each do |e|
      msg = -"process_groups: #{e}"
      qb = build_query_obj(query = "aaa ( bbb status:any )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa status:any ) )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa deletedby:someone ) )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
      qb = build_query_obj(query = "aaa ( bbb ( aaa delreason:something ) status:pending )", process_groups: e)
      assert_not(has_deleted_with?(qb, false), "#{query} #{msg} #{qb}")
    end
    # assert_includes(ElasticPostQueryBuilder.new("status:pending", resolve_aliases: true, free_tags_count: 0, enable_safe_mode: false, always_show_deleted: false).create_query_obj, { term: { pending: true } })
  end
end
