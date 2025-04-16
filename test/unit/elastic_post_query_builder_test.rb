# frozen_string_literal: true

require "test_helper"

class ElasticPostQueryBuilderTest < ActiveSupport::TestCase
  ORDER_MAP = Hash.new([{ id: :desc }]).merge(
    {
      "id" => [{ id: :asc }],
      "id_asc" => [{ id: :asc }],
      "id_desc" => [{ id: :desc }],
      "change" => [{ change_seq: :desc }],
      "change_desc" => [{ change_seq: :desc }],
      "change_asc" => [{ change_seq: :asc }],
      "md5" => [{ md5: :desc }],
      "md5_desc" => [{ md5: :desc }],
      "md5_asc" => [{ md5: :asc }],
      "score" => [{ score: :desc }, { id: :desc }],
      "score_desc" => [{ score: :desc }, { id: :desc }],
      "score_asc" => [{ score: :asc }, { id: :asc }],
      "duration" => [{ duration: :desc }, { id: :desc }],
      "duration_desc" => [{ duration: :desc }, { id: :desc }],
      "duration_asc" => [{ duration: :asc }, { id: :asc }],
      "favcount" => [{ fav_count: :desc }, { id: :desc }],
      "favcount_desc" => [{ fav_count: :desc }, { id: :desc }],
      "favcount_asc" => [{ fav_count: :asc }, { id: :asc }],
      "created_at" => [{ created_at: :desc }],
      "created_at_desc" => [{ created_at: :desc }],
      "created_at_asc" => [{ created_at: :asc }],
      "created" => [{ created_at: :desc }],
      "created_desc" => [{ created_at: :desc }],
      "created_asc" => [{ created_at: :asc }],
      "updated_at" => [{ updated_at: :desc }, { id: :desc }],
      "updated_at_desc" => [{ updated_at: :desc }, { id: :desc }],
      "updated_at_asc" => [{ updated_at: :asc }, { id: :asc }],
      "updated" => [{ updated_at: :desc }, { id: :desc }],
      "updated_desc" => [{ updated_at: :desc }, { id: :desc }],
      "updated_asc" => [{ updated_at: :asc }, { id: :asc }],
      "comment" => [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comment_desc" => [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comment_asc" => [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }],
      "comm" => [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comm_desc" => [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comm_asc" => [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }],
      "comment_bumped" => [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comment_bumped_desc" => [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comment_bumped_asc" => [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }],
      "comm_bumped" => [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comm_bumped_desc" => [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }],
      "comm_bumped_asc" => [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }],
      "note" => [{ noted_at: { order: :desc, missing: :_last } }],
      "note_desc" => [{ noted_at: { order: :desc, missing: :_last } }],
      "note_asc" => [{ noted_at: { order: :asc, missing: :_first } }],
      "mpixels" => [{ mpixels: :desc }],
      "mpixels_desc" => [{ mpixels: :desc }],
      "mpixels_asc" => [{ mpixels: :asc }],
      "portrait" => [{ aspect_ratio: :asc }],
      "landscape" => [{ aspect_ratio: :desc }],
      "ratio_asc" => [{ aspect_ratio: :asc }],
      "ratio" => [{ aspect_ratio: :desc }],
      "ratio_desc" => [{ aspect_ratio: :desc }],
      "aspect_ratio_asc" => [{ aspect_ratio: :asc }],
      "aspect_ratio" => [{ aspect_ratio: :desc }],
      "aspect_ratio_desc" => [{ aspect_ratio: :desc }],
      "filesize" => [{ file_size: :desc }],
      "filesize_desc" => [{ file_size: :desc }],
      "filesize_asc" => [{ file_size: :asc }],
      "tagcount" => [{ tag_count: :desc }],
      "tagcount_desc" => [{ tag_count: :desc }],
      "tagcount_asc" => [{ tag_count: :asc }],
      "rank" => [{ _score: :desc }],
      "random" => [{ _score: :desc }],
    },
    # /\A(?<column>#{TagQuery::COUNT_METATAGS.join('|')})(_(?<direction>asc))?\z/i
    # column = Regexp.last_match[:column]
    # direction = Regexp.last_match[:direction] || "desc"
    # [{ column => direction }, { id: direction }]
    TagQuery::COUNT_METATAGS.flat_map { |e| [e, -"#{e}_desc", -"#{e}_asc"] }.index_with { |e| [{ e.delete_suffix("_asc").delete_suffix("_desc") => e.end_with?("_asc") ? "asc" : "desc" }, { id: e.end_with?("_asc") ? "asc" : "desc" }] },
    # /(#{TagCategory::SHORT_NAME_REGEX})tags/
    # {"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :desc},
    # /(#{TagCategory::SHORT_NAME_REGEX})tags_asc/
    # {"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :asc},
    *TagQuery::CATEGORY_METATAG_MAP.each_pair.map { |k, v| { k => [{ v => :desc }], -"#{k}_desc" => [{ v => :desc }], -"#{k}_asc" => [{ v => :asc }] } },
  ).freeze
  # For `ActiveSupport::TimeWithZone` comparisons using `assert_in_delta`, the maximal difference
  # between expected & actual in seconds. Set to 5 seconds. Needed b/c the actual and expected
  # `ActiveSupport::TimeWithZone`s can't be constructed at the same time.
  TIME_DELTA = 5.0
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

    should "only have an order at the root" do
      assert_equal(ElasticPostQueryBuilder::ORDER_TABLE["score"], ElasticPostQueryBuilder.new("order:favcount ( order:score )", **DEFAULT_PARAM).order)
    end

    should "properly handle locked metatags" do
      assert_includes(ElasticPostQueryBuilder.new("locked:rating", **DEFAULT_PARAM).must, { term: { rating_locked: true } }, "locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("locked:note", **DEFAULT_PARAM).must, { term: { note_locked: true } }, "locked:note")
      assert_includes(ElasticPostQueryBuilder.new("locked:status", **DEFAULT_PARAM).must, { term: { status_locked: true } }, "locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("locked:whatever", **DEFAULT_PARAM).must, { term: { "missing" => true } }, "locked:whatever")

      assert_includes(ElasticPostQueryBuilder.new("-locked:rating", **DEFAULT_PARAM).must, { term: { rating_locked: false } }, "-locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("-locked:note", **DEFAULT_PARAM).must, { term: { note_locked: false } }, "-locked:note")
      assert_includes(ElasticPostQueryBuilder.new("-locked:status", **DEFAULT_PARAM).must, { term: { status_locked: false } }, "-locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("-locked:whatever", **DEFAULT_PARAM).must, { term: { "missing" => false } }, "-locked:whatever")

      assert_includes(ElasticPostQueryBuilder.new("~locked:rating", **DEFAULT_PARAM).should, { term: { rating_locked: true } }, "~locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("~locked:note", **DEFAULT_PARAM).should, { term: { note_locked: true } }, "~locked:note")
      assert_includes(ElasticPostQueryBuilder.new("~locked:status", **DEFAULT_PARAM).should, { term: { status_locked: true } }, "~locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("~locked:whatever", **DEFAULT_PARAM).should, { term: { "missing" => true } }, "~locked:whatever")

      assert_includes(ElasticPostQueryBuilder.new("ratinglocked:true", **DEFAULT_PARAM).must, { term: { rating_locked: true } }, "ratinglocked:true")
      assert_includes(ElasticPostQueryBuilder.new("ratinglocked:false", **DEFAULT_PARAM).must, { term: { rating_locked: false } }, "ratinglocked:false")
      assert_includes(ElasticPostQueryBuilder.new("notelocked:true", **DEFAULT_PARAM).must, { term: { note_locked: true } }, "notelocked:true")
      assert_includes(ElasticPostQueryBuilder.new("notelocked:false", **DEFAULT_PARAM).must, { term: { note_locked: false } }, "notelocked:false")
      assert_includes(ElasticPostQueryBuilder.new("statuslocked:true", **DEFAULT_PARAM).must, { term: { status_locked: true } }, "statuslocked:true")
      assert_includes(ElasticPostQueryBuilder.new("statuslocked:false", **DEFAULT_PARAM).must, { term: { status_locked: false } }, "statuslocked:false")
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

    should "properly parse order metatags" do
      t_map = {
        asc: :desc,
        desc: :asc,
        "asc" => "desc",
        "desc" => "asc",
      }.freeze
      invert = ->(ov) do
        if ov.is_a?(Hash)
          ov.transform_values(&invert)
        else
          t_map[ov] || ov
        end
      end.freeze
      ORDER_MAP.each_pair do |k, v| # rubocop:disable Metrics/BlockLength
        if TagQuery.normalize_order_value("order:#{k}") == TagQuery.normalize_order_value("-order:#{k}") # rubocop:disable Metrics/BlockLength
          [""]
        else
          ["", "-"]
        end.each do |p|
          q = -"#{p}order:#{k}"
          r = ElasticPostQueryBuilder.new(q, **DEFAULT_PARAM)
          comparison = 2.days.ago if k == "rank"
          msg = -"val: #{k}, TQ(#{q}).q:#{TagQuery.new(q).q}"
          expected_result = if p == "-"
                              if %w[comment_bumped_desc comm_bumped_desc comment_bumped comm_bumped].include?(k)
                                ORDER_MAP["comment_bumped_asc"]
                              elsif %w[comment_bumped_asc comm_bumped_asc].include?(k)
                                ORDER_MAP["comment_bumped_desc"]
                              elsif %w[note_desc note].include?(k)
                                ORDER_MAP["note_asc"]
                              elsif k == "note_asc"
                                ORDER_MAP["note"]
                              elsif %w[rank random].include?(k)
                                v
                              else
                                v.map { |e| e.transform_values(&invert) }
                              end
                            else
                              v
                            end
          assert_equal(expected_result, r.order, msg)
          case k
          when /\Acomm(?>ent)?_bumped(?>_(?>a|de)sc)?\z/
            assert_includes(r.must, { exists: { field: "comment_bumped_at" } }, msg)
          when "rank"
            assert_includes(r.must, { range: { score: { gt: 0 } } }, msg)
            datetime_ago = nil
            assert(r.must.any? { |x| datetime_ago ||= x[:range]&.fetch(:created_at, nil)&.fetch(:gte, nil) }, msg)
            assert_in_delta(comparison, datetime_ago, TIME_DELTA, msg)
          # FIXME: Find a way to test the function score and assert these commented out lines
          #   assert_equals({
          #     script_score: {
          #       script: {
          #         params: { log3: Math.log(3), date2005_05_24: 1_116_936_000 },
          #         source: "Math.log(doc['score'].value) / params.log3 + (doc['created_at'].value.millis / 1000 - params.date2005_05_24) / 35000",
          #       },
          #     },
          #   }, @function_score)
          # when "random"
          #   assert_equals({
          #     random_score: r.q[:random_seed].present? ? { seed: r.q[:random_seed], field: "id" } : {},
          #     boost_mode: :replace,
          #   }, r.@function_score) # rubocop:disable Layout/CommentIndentation
          end
        end
      end
    end
  end
end
