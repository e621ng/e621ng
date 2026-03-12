# frozen_string_literal: true

require "test_helper"

class ElasticPostQueryBuilderTest < ActiveSupport::TestCase
  # A map of all valid `order` metatag inputs to their normal (`value.first`) & reversed
  # (`value.last`) parsed values.
  ORDER_MAP = Hash.new([{ id: :desc }]).merge(
    {
      "id" => [[{ id: :asc }], [{ id: :desc }]],
      "id_asc" => [[{ id: :asc }], [{ id: :desc }]],
      "id_desc" => [[{ id: :desc }], [{ id: :asc }]],
      "change" => [[{ change_seq: :desc }], [{ change_seq: :asc }]],
      "change_desc" => [[{ change_seq: :desc }], [{ change_seq: :asc }]],
      "change_asc" => [[{ change_seq: :asc }], [{ change_seq: :desc }]],
      "md5" => [[{ md5: :desc }], [{ md5: :asc }]],
      "md5_desc" => [[{ md5: :desc }], [{ md5: :asc }]],
      "md5_asc" => [[{ md5: :asc }], [{ md5: :desc }]],
      "score" => [[{ score: :desc }, { id: :desc }], [{ score: :asc }, { id: :asc }]],
      "score_desc" => [[{ score: :desc }, { id: :desc }], [{ score: :asc }, { id: :asc }]],
      "score_asc" => [[{ score: :asc }, { id: :asc }], [{ score: :desc }, { id: :desc }]],
      "duration" => [[{ duration: :desc }, { id: :desc }], [{ duration: :asc }, { id: :asc }]],
      "duration_desc" => [[{ duration: :desc }, { id: :desc }], [{ duration: :asc }, { id: :asc }]],
      "duration_asc" => [[{ duration: :asc }, { id: :asc }], [{ duration: :desc }, { id: :desc }]],
      "favcount" => [[{ fav_count: :desc }, { id: :desc }], [{ fav_count: :asc }, { id: :asc }]],
      "favcount_desc" => [[{ fav_count: :desc }, { id: :desc }], [{ fav_count: :asc }, { id: :asc }]],
      "favcount_asc" => [[{ fav_count: :asc }, { id: :asc }], [{ fav_count: :desc }, { id: :desc }]],
      "created_at" => [[{ created_at: :desc }], [{ created_at: :asc }]],
      "created_at_desc" => [[{ created_at: :desc }], [{ created_at: :asc }]],
      "created_at_asc" => [[{ created_at: :asc }], [{ created_at: :desc }]],
      "created" => [[{ created_at: :desc }], [{ created_at: :asc }]],
      "created_desc" => [[{ created_at: :desc }], [{ created_at: :asc }]],
      "created_asc" => [[{ created_at: :asc }], [{ created_at: :desc }]],
      "updated_at" => [[{ updated_at: :desc }, { id: :desc }], [{ updated_at: :asc }, { id: :asc }]],
      "updated_at_desc" => [[{ updated_at: :desc }, { id: :desc }], [{ updated_at: :asc }, { id: :asc }]],
      "updated_at_asc" => [[{ updated_at: :asc }, { id: :asc }], [{ updated_at: :desc }, { id: :desc }]],
      "updated" => [[{ updated_at: :desc }, { id: :desc }], [{ updated_at: :asc }, { id: :asc }]],
      "updated_desc" => [[{ updated_at: :desc }, { id: :desc }], [{ updated_at: :asc }, { id: :asc }]],
      "updated_asc" => [[{ updated_at: :asc }, { id: :asc }], [{ updated_at: :desc }, { id: :desc }]],
      "comment" => [[{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }]],
      "comment_desc" => [[{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }]],
      "comment_asc" => [[{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }], [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }]],
      "comm" => [[{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }]],
      "comm_desc" => [[{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }]],
      "comm_asc" => [[{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }], [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }]],
      "comment_bumped" => [[{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }]],
      "comment_bumped_desc" => [[{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }]],
      "comment_bumped_asc" => [[{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }]],
      "comm_bumped" => [[{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }]],
      "comm_bumped_desc" => [[{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }]],
      "comm_bumped_asc" => [[{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }], [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }]],
      "note" => [[{ noted_at: { order: :desc, missing: :_last } }], [{ noted_at: { order: :asc, missing: :_first } }]],
      "note_desc" => [[{ noted_at: { order: :desc, missing: :_last } }], [{ noted_at: { order: :asc, missing: :_first } }]],
      "note_asc" => [[{ noted_at: { order: :asc, missing: :_first } }], [{ noted_at: { order: :desc, missing: :_last } }]],
      "mpixels" => [[{ mpixels: :desc }], [{ mpixels: :asc }]],
      "mpixels_desc" => [[{ mpixels: :desc }], [{ mpixels: :asc }]],
      "mpixels_asc" => [[{ mpixels: :asc }], [{ mpixels: :desc }]],
      "ratio" => [[{ aspect_ratio: :desc }], [{ aspect_ratio: :asc }]],
      "ratio_desc" => [[{ aspect_ratio: :desc }], [{ aspect_ratio: :asc }]],
      "ratio_asc" => [[{ aspect_ratio: :asc }], [{ aspect_ratio: :desc }]],
      "aspect_ratio" => [[{ aspect_ratio: :desc }], [{ aspect_ratio: :asc }]],
      "aspect_ratio_desc" => [[{ aspect_ratio: :desc }], [{ aspect_ratio: :asc }]],
      "aspect_ratio_asc" => [[{ aspect_ratio: :asc }], [{ aspect_ratio: :desc }]],
      "filesize" => [[{ file_size: :desc }], [{ file_size: :asc }]],
      "filesize_desc" => [[{ file_size: :desc }], [{ file_size: :asc }]],
      "filesize_asc" => [[{ file_size: :asc }], [{ file_size: :desc }]],
      "size" => [[{ file_size: :desc }], [{ file_size: :asc }]],
      "size_desc" => [[{ file_size: :desc }], [{ file_size: :asc }]],
      "size_asc" => [[{ file_size: :asc }], [{ file_size: :desc }]],
      "tagcount" => [[{ tag_count: :desc }], [{ tag_count: :asc }]],
      "tagcount_desc" => [[{ tag_count: :desc }], [{ tag_count: :asc }]],
      "tagcount_asc" => [[{ tag_count: :asc }], [{ tag_count: :desc }]],
      "hot" => [[{ _score: :desc }]],
      "rank" => [[{ _score: :desc }]],
      "random" => [[{ _score: :desc }]],
      "portrait" => [[{ aspect_ratio: :asc }], [{ aspect_ratio: :desc }]],
      "landscape" => [[{ aspect_ratio: :desc }], [{ aspect_ratio: :asc }]],
    },
    TagQuery::COUNT_METATAGS
      .flat_map { |e| [e, -"#{e}_desc", -"#{e}_asc"] + (e.include?("comment") ? [e.gsub("comment", "comm").freeze, -"#{e.gsub('comment', 'comm')}_desc", -"#{e.gsub('comment', 'comm')}_asc"] : []) }
      .index_with do |e|
      k = e.delete_suffix("_asc").delete_suffix("_desc")
      k = k.gsub("comm", "comment").freeze if /comm(?!ent)/.match?(k)
      v = e.end_with?("_asc") ? "asc" : "desc"
      v_reversed = e.end_with?("_asc") ? "desc" : "asc"
      [[{ k => v }, { id: v }], [{ k => v_reversed }, { id: v_reversed }]]
    end,
    *TagQuery::CATEGORY_METATAG_MAP.each_pair.map do |k, v|
      descending = [[{ v => :desc }], [{ v => :asc }]]
      ascending = [[{ v => :asc }], [{ v => :desc }]]
      {
        k => descending,
        -"#{k}_desc" => descending,
        -"#{k}_asc" => ascending,
        # # Adds `artisttags`
        # -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}tags" => descending,
        # -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}tags_desc" => descending,
        # -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}tags_asc" => ascending,
        # # Adds `art_tags`
        # -"#{k.delete_suffix('tags')}_tags" => descending,
        # -"#{k.delete_suffix('tags')}_tags_desc" => descending,
        # -"#{k.delete_suffix('tags')}_tags_asc" => ascending,
        # Adds `artist_tags`
        -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}_tags" => descending,
        -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}_tags_desc" => descending,
        -"#{TagCategory::SHORT_NAME_MAPPING[k.delete_suffix('tags')]}_tags_asc" => ascending,
      }
    end,
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

  should "be testing all valid order values" do
    # assert((d = (TagQuery::ORDER_METATAGS - ORDER_MAP.keys) + ))
    msg = -"Diff: #{(TagQuery::ORDER_METATAGS - ORDER_MAP.keys) + (ORDER_MAP.keys - TagQuery::ORDER_METATAGS)}\nTagQuery::ORDER_METATAGS: #{TagQuery::ORDER_METATAGS};\nORDER_MAP.keys: #{ORDER_MAP.keys}"
    assert_equal(TagQuery::ORDER_METATAGS.length, ORDER_MAP.keys.length, msg)
    assert_equal(TagQuery::ORDER_METATAGS, TagQuery::ORDER_METATAGS.intersection(ORDER_MAP.keys), msg)
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

    should "gracefully ignore dates with years outside OpenSearch range" do
      query_invalid = build_query("date:23025-05-24")
      assert(query_invalid.has_invalid_input, "Should detect invalid date input")

      query_valid = build_query("date:2025-05-24")
      assert_not(query_valid.has_invalid_input, "Should not flag valid date as invalid")
      assert(query_valid.must.any? { |m| m.dig(:range, :created_at) }, "Valid date should add date range to query")
    end

    should "properly handle locked metatags" do
      assert_includes(ElasticPostQueryBuilder.new("locked:rating", **DEFAULT_PARAM).must, { term: { rating_locked: true } }, "locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("locked:note", **DEFAULT_PARAM).must, { term: { note_locked: true } }, "locked:note")
      assert_includes(ElasticPostQueryBuilder.new("locked:status", **DEFAULT_PARAM).must, { term: { status_locked: true } }, "locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("locked:whatever", **DEFAULT_PARAM).must, { term: { "missing" => true } }, "locked:whatever")
      assert((v = ElasticPostQueryBuilder.new("locked:whatever", **DEFAULT_PARAM, always_show_deleted: true).must).empty?, "locked:whatever: #{v}")

      assert_includes(ElasticPostQueryBuilder.new("-locked:rating", **DEFAULT_PARAM).must, { term: { rating_locked: false } }, "-locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("-locked:note", **DEFAULT_PARAM).must, { term: { note_locked: false } }, "-locked:note")
      assert_includes(ElasticPostQueryBuilder.new("-locked:status", **DEFAULT_PARAM).must, { term: { status_locked: false } }, "-locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("-locked:whatever", **DEFAULT_PARAM).must, { term: { "missing" => false } }, "-locked:whatever")
      assert((v = ElasticPostQueryBuilder.new("-locked:whatever", **DEFAULT_PARAM, always_show_deleted: true).must).empty?, "-locked:whatever: #{v}")

      assert_includes(ElasticPostQueryBuilder.new("~locked:rating", **DEFAULT_PARAM).should, { term: { rating_locked: true } }, "~locked:rating")
      assert_includes(ElasticPostQueryBuilder.new("~locked:note", **DEFAULT_PARAM).should, { term: { note_locked: true } }, "~locked:note")
      assert_includes(ElasticPostQueryBuilder.new("~locked:status", **DEFAULT_PARAM).should, { term: { status_locked: true } }, "~locked:status")
      # assert_includes(ElasticPostQueryBuilder.new("~locked:whatever", **DEFAULT_PARAM).should, { term: { "missing" => true } }, "~locked:whatever")
      assert((v = ElasticPostQueryBuilder.new("~locked:whatever", **DEFAULT_PARAM, always_show_deleted: true).must).empty?, "~locked:whatever: #{v}")

      assert_includes(ElasticPostQueryBuilder.new("ratinglocked:true", **DEFAULT_PARAM).must, { term: { rating_locked: true } }, "ratinglocked:true")
      assert_includes(ElasticPostQueryBuilder.new("ratinglocked:false", **DEFAULT_PARAM).must, { term: { rating_locked: false } }, "ratinglocked:false")
      assert_includes(ElasticPostQueryBuilder.new("ratinglocked:anything", **DEFAULT_PARAM).must, { term: { rating_locked: false } }, "ratinglocked:anything")
      assert_includes(ElasticPostQueryBuilder.new("notelocked:true", **DEFAULT_PARAM).must, { term: { note_locked: true } }, "notelocked:true")
      assert_includes(ElasticPostQueryBuilder.new("notelocked:false", **DEFAULT_PARAM).must, { term: { note_locked: false } }, "notelocked:false")
      assert_includes(ElasticPostQueryBuilder.new("notelocked:anything", **DEFAULT_PARAM).must, { term: { note_locked: false } }, "notelocked:anything")
      assert_includes(ElasticPostQueryBuilder.new("statuslocked:true", **DEFAULT_PARAM).must, { term: { status_locked: true } }, "statuslocked:true")
      assert_includes(ElasticPostQueryBuilder.new("statuslocked:false", **DEFAULT_PARAM).must, { term: { status_locked: false } }, "statuslocked:false")
      assert_includes(ElasticPostQueryBuilder.new("statuslocked:anything", **DEFAULT_PARAM).must, { term: { status_locked: false } }, "statuslocked:anything")

      # TODO: Add tests for `~` & `-` prefixed `___locked` tags being processed as tags & not metatags
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
      ORDER_MAP.each_pair do |k, v|
        if TagQuery.normalize_order_value("order:#{k}") == TagQuery.normalize_order_value("-order:#{k}")
          [""]
        else
          ["", "-"]
        end.each do |p|
          q = -"#{p}order:#{k}"
          r = ElasticPostQueryBuilder.new(q, **DEFAULT_PARAM)
          comparison = 2.days.ago if %w[hot rank].include?(k)
          msg = -"val: #{k}, TQ(#{q}).q:#{TagQuery.new(q).q}"
          assert_equal(p == "-" ? v.last : v.first, r.order, msg)

          # Extra checks for elements that change more than the `order` property.
          case k
          when /\Acomm(?>ent)?_bumped(?>_(?>a|de)sc)?\z/
            assert_includes(r.must, { exists: { field: "comment_bumped_at" } }, msg)
          when "hot", "rank" # TODO: Test with `hot_from`
            assert_includes(r.must, { range: { score: { gt: 0 } } }, msg)
            datetime_ago = nil
            assert(r.must.any? { |x| datetime_ago ||= x[:range]&.fetch(:created_at, nil)&.fetch(:gte, nil) }, msg)
            assert_in_delta(comparison, datetime_ago, TIME_DELTA, msg)
          # FIXME: Find a way to test the function score and assert these commented out lines
          # TODO: Check with `hot`
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
