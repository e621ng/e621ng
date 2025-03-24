# frozen_string_literal: true

require "test_helper"

class TagQueryTest < ActiveSupport::TestCase
  context "While using simple scanning" do
    should "scan a query" do
      assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
      assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan("~AAa -BBB* -bbb*"))
      # Order is now preserved
      assert_equal(["aaa", 'test:"with spaces"', "def"], TagQuery.scan('aaa test:"with spaces" def'))
    end

    should "not strip out valid characters when scanning" do
      assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    end
  end

  context "While using light scanning" do
    should "scan a query" do
      assert_equal(%w[aaa bbb], TagQuery.scan_light("aaa bbb"))
      assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan_light("~AAa -BBB* -bbb*"))
      assert_equal(['test:"with spaces"', TagQuery::END_OF_METATAGS_TOKEN, "aaa", "def"], TagQuery.scan_light('aaa test:"with spaces" def'))
      assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan_light('aaa test:"with spaces" def', delim_metatags: false))
    end

    should "not strip out valid characters when scanning" do
      assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan_light("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    end
  end

  context "While scan_searching" do
    should "behave identically to the simple variant when no groups exist" do
      # scan a query
      assert_equal(TagQuery.scan("aaa bbb"), TagQuery.scan_search("aaa bbb"))
      assert_equal(TagQuery.scan("~AAa -BBB* -bbb*"), TagQuery.scan_search("~AAa -BBB* -bbb*"))
      assert_equal(TagQuery.scan('aaa test:"with spaces" def'), TagQuery.scan_search('aaa test:"with spaces" def', delim_metatags: false))
      # not strip out valid characters when scanning
      assert_equal(TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"), TagQuery.scan_search("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    end

    should "behave similarly to the light variant when no groups exist" do
      # scan a query
      assert_equal(TagQuery.scan_light("aaa bbb"), TagQuery.scan_search("aaa bbb"))
      assert_equal(TagQuery.scan_light("~AAa -BBB* -bbb*"), TagQuery.scan_search("~AAa -BBB* -bbb*"))
      sl = TagQuery.scan_light('aaa test:"with spaces" def')
      ss = TagQuery.scan_search('aaa test:"with spaces" def')
      assert_not_equal(sl, ss)
      sl = TagQuery.scan_light('aaa test:"with spaces" def', delim_metatags: false)
      ss = TagQuery.scan_search('aaa test:"with spaces" def')
      assert_equal([], sl - ss, "scan_light #{sl} - scan_search #{ss} should be empty")
      # not strip out valid characters when scanning
      sl = TagQuery.scan_light("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%")
      ss = TagQuery.scan_search("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%")
      assert_equal(sl, ss)
    end

    context "a query w/o nested groups" do
      should "pull out a lone top-level group without a modifier" do
        assert_equal(%w[aaa bbb], TagQuery.scan_search("( aaa bbb )"))
      end

      should "not pull out a lone top-level group with a modifier" do
        assert_equal(["-( aaa bbb )"], TagQuery.scan_search("-( aaa bbb )"))
      end

      should "properly handle simple groups" do
        assert_equal(["( aaa )", "-( bbb )"], TagQuery.scan_search("( aaa ) -( bbb )"))
        assert_equal(["~( AAa -BBB* )", "-bbb*"], TagQuery.scan_search("~( AAa -BBB* ) -bbb*"))
      end

      should "hoist metatags" do
        assert_equal(["order:random", "limit:50", "( aaa )", "randseed:123", "-( bbb )"], TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"))
        assert_equal(["order:random", "limit:50", "randseed:123", "( aaa )", "-( bbb )"], TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )", segregate_metatags: true, delim_metatags: false))
        assert_equal(["order:random", "limit:50", "randseed:123", TagQuery::END_OF_METATAGS_TOKEN, "( aaa )", "-( bbb )"], TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )", segregate_metatags: true))
        assert_equal("random", TagQuery.new("( order:random aaa limit:50 ) -( bbb randseed:123 )")[:order])
        assert_equal(123, TagQuery.new("( order:random aaa limit:50 ) -( bbb randseed:123 )")[:random_seed])
      end
    end

    context "a query with nested groups" do
      # should "not pull out a lone top-level group without a modifier but with an interior group" do
      #   assert_equal("( ( aaa bbb ) )", TagQuery.scan_search("( ( aaa bbb ) )"))
      should "pull out a lone top-level group without a modifier but with an interior group" do
        assert_equal(%w[aaa bbb], TagQuery.scan_search("( ( aaa bbb ) )"))
      end

      should "not pull out a lone top-level group with a modifier and an interior group" do
        assert_equal(["-( ( aaa bbb ) )"], TagQuery.scan_search("-( ( aaa bbb ) )"))
      end

      should "properly handle simple groups" do
        assert_equal(["( ( aaa ) )", "-( ( bbb ) )"], TagQuery.scan_search("( ( aaa ) ) -( ( bbb ) )"))
        assert_equal(["~( AAa -BBB* )", "-bbb*"], TagQuery.scan_search("( ~( AAa -BBB* ) -bbb* )"))
      end

      should "hoist metatags" do
        input_str = "( ( order:random ) aaa limit:50 ) -( bbb -( randseed:123 ) )"
        assert_equal(["order:random", "limit:50", "( (  ) aaa )", "randseed:123", "-( bbb -(  ) )"], TagQuery.scan_search(input_str, filter_empty_groups: false))
        assert_equal(["order:random", "limit:50", "( aaa )", "randseed:123", "-( bbb )"], TagQuery.scan_search(input_str))
        assert_equal(["order:random", "limit:50", "randseed:123", "( aaa )", "-( bbb )"], TagQuery.scan_search(input_str, segregate_metatags: true, delim_metatags: false))
        assert_equal(["order:random", "limit:50", "randseed:123", TagQuery::END_OF_METATAGS_TOKEN, "( aaa )", "-( bbb )"], TagQuery.scan_search(input_str, segregate_metatags: true))
        assert_equal(["order:random", "limit:50", "randseed:123", "( (  ) aaa )", "-( bbb -(  ) )"], TagQuery.scan_search(input_str, filter_empty_groups: false, segregate_metatags: true, delim_metatags: false))
        assert_equal(["order:random", "limit:50", "randseed:123", "( aaa )", "-( bbb )"], TagQuery.scan_search(input_str, segregate_metatags: true, delim_metatags: false))
        assert_equal(["order:random", "limit:50", "randseed:123", TagQuery::END_OF_METATAGS_TOKEN, "( (  ) aaa )", "-( bbb -(  ) )"], TagQuery.scan_search(input_str, filter_empty_groups: false, segregate_metatags: true))
        assert_equal(["order:random", "limit:50", "randseed:123", TagQuery::END_OF_METATAGS_TOKEN, "( aaa )", "-( bbb )"], TagQuery.scan_search(input_str, segregate_metatags: true))
        assert_equal("random", TagQuery.new(input_str)[:order])
        assert_equal(123, TagQuery.new(input_str)[:random_seed])
      end
    end
  end

  context "While fetching tags" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags([(0..(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, _| "( #{accumulator} )" }], "aaa", error_on_depth_exceeded: true)
      end
      # non-top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags(["a", (0..(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, _| "( a #{accumulator} )" }], "aaa", recurse: true, error_on_depth_exceeded: true)
      end
      # mixed level query
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags(["a", (0..(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, v| "#{v.even? ? '( a ' : '( '}#{accumulator} )" }], "aaa", recurse: true, error_on_depth_exceeded: true)
      end
    end

    should "not fail for less than or equal to #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      TagQuery.fetch_tags([(0...(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, _| "( #{accumulator} )" }], "aaa", error_on_depth_exceeded: true)
      # non-top level
      TagQuery.fetch_tags(["a", (0...(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, _| "( a #{accumulator} )" }], "aaa", recurse: true, error_on_depth_exceeded: true)
      # mixed level query
      TagQuery.fetch_tags(["a", (0...(TagQuery::DEPTH_LIMIT - 1)).inject("aaa") { |accumulator, v| "#{v.even? ? '( a ' : '( '}#{accumulator} )" }], "aaa", recurse: true, error_on_depth_exceeded: true)
    end

    should "fetch when shallowly nested" do
      assert_equal(["aaa"], TagQuery.fetch_tags(TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"), "aaa", recurse: true))
      assert_equal(%w[aaa bbb], TagQuery.fetch_tags(TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"), "aaa", "bbb", recurse: true))
    end

    should "fetch when deeply nested" do
      input_str = "( -( order:random ( aaa ) ) limit:50 ) -( ~( bbb ) randseed:123 )"
      assert_equal(["aaa"], TagQuery.fetch_tags(TagQuery.scan_search(input_str), "aaa", recurse: true))
      assert_equal(%w[aaa bbb], TagQuery.fetch_tags(TagQuery.scan_search(input_str), "aaa", "bbb", recurse: true))
    end
  end

  # TODO: Add tests for prepend_prefix
  context "While fetching metatags" do
    # This should be enabled if the implementation of `TagQuery.fetch_metatag` changes to be recursive.
    # should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
    #   # top level
    #   assert_raise(TagQuery::DepthExceededError) do
    #     TagQuery.fetch_metatag(
    #       [(0..(TagQuery::DEPTH_LIMIT - 1)).inject("bbb:aaa") { |accumulator, _| "( #{accumulator} )" }],
    #       "bbb", at_any_level: true
    #     )
    #   end
    #   # non-top level
    #   assert_raise(TagQuery::DepthExceededError) do
    #     TagQuery.fetch_metatag(
    #       ["a", "( #{(0..(TagQuery::DEPTH_LIMIT - 1)).inject('bbb:aaa') { |accumulator, _| "a ( #{accumulator} )" }} )"],
    #       "bbb", at_any_level: true
    #     )
    #   end
    #   # mixed level query
    #   assert_raise(TagQuery::DepthExceededError) do
    #     TagQuery.fetch_metatag(
    #       ["a", "( #{(0..(TagQuery::DEPTH_LIMIT - 1)).inject('bbb:aaa') { |accumulator, v| "#{v.even? ? 'a ' : ''}( #{accumulator} )" }} )"],
    #       "bbb", at_any_level: true
    #     )
    #   end
    # end

    should "fetch when shallowly nested" do
      input_str = "( order:random aaa meta:tag ) -( bbb randseed:123 )"
      assert_equal(
        "123",
        TagQuery.fetch_metatag(input_str, "randseed", at_any_level: true),
      )
      # Check a array w/ group strings
      assert_equal(
        "123",
        TagQuery.fetch_metatag(TagQuery.scan_search(input_str), "randseed", at_any_level: true),
      )
      # ORDER
      assert_equal(
        "tag",
        TagQuery.fetch_metatag(input_str, "meta", "randseed", at_any_level: true),
      )
      # Check a array w/ group strings
      assert_equal(
        "tag",
        TagQuery.fetch_metatag(TagQuery.scan_search(input_str), "meta", "randseed", at_any_level: true),
      )
    end

    should "fetch when deeply nested" do
      input_str = "( order:random -( aaa ~( meta:tag ) ) ) -( bbb -( randseed:123 ) )"
      assert_equal(
        "123",
        TagQuery.fetch_metatag(input_str, "randseed", at_any_level: true),
      )
      # Check a array w/ group strings
      assert_equal(
        "123",
        TagQuery.fetch_metatag(TagQuery.scan_search(input_str), "randseed", at_any_level: true),
      )
      # ORDER
      assert_equal(
        "tag",
        TagQuery.fetch_metatag(input_str, "meta", "randseed", at_any_level: true),
      )
      # Check a array w/ group strings
      assert_equal(
        "tag",
        TagQuery.fetch_metatag(TagQuery.scan_search(input_str), "meta", "randseed", at_any_level: true),
      )
    end
  end

  # TODO: Add distribute prefixes tests
  context "While recursively scanning" do
    setup do
      @kwargs = {
        strip_duplicates_at_level: false,
        delimit_groups: true,
        flatten: true,
        strip_prefixes: false,
        sort_at_level: false,
        normalize_at_level: false,
        error_on_depth_exceeded: false,
      }
    end

    should "behave identically to the other variants when no groups exist using default options" do
      # scan a query
      assert_equal(TagQuery.scan("aaa bbb"), TagQuery.scan_recursive("aaa bbb"))
      assert_equal(TagQuery.scan("~AAa -BBB* -bbb*"), TagQuery.scan_recursive("~AAa -BBB* -bbb*"))
      assert_equal(TagQuery.scan('aaa test:"with spaces" def'), TagQuery.scan_recursive('aaa test:"with spaces" def'))
      # not strip out valid characters when scanning
      assert_equal(TagQuery.scan("aaa bbb"), TagQuery.scan_recursive("aaa bbb"))
      assert_equal(TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"), TagQuery.scan_recursive("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    end

    should "behave identically to non-recursive variant with a single top-level group with no modifier when not delimiting groups" do
      assert_equal(TagQuery.scan_search("( aaa bbb )"), TagQuery.scan_recursive("( aaa bbb )", delimit_groups: false))
    end

    should "properly handle the base case" do
      assert_equal(["(", "aaa", "bbb", ")"], TagQuery.scan_recursive("( aaa bbb )"))
      assert_equal(
        ["~(", "AAa", "-BBB*", ")", "-bbb*"],
        TagQuery.scan_recursive(
          "~( AAa -BBB* ) -bbb*",
          **@kwargs,
        ),
        **@kwargs,
      )
    end

    context "& flattening" do
      should "properly strip prefixes" do
        assert_equal(
          ["(", "aaa", "bbb", ")"],
          TagQuery.scan_recursive(
            "-( ~aaa -bbb )",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
      end

      should "properly preserve prefixes" do
        assert_equal(
          ["-(", "~aaa", "-bbb", ")"],
          TagQuery.scan_recursive(
            "-( ~aaa -bbb )",
            **@kwargs,
          ),
          **@kwargs,
        )
        assert_equal(
          ["-", "~aaa", "-bbb"],
          TagQuery.scan_recursive(
            "-( ~aaa -bbb )",
            **@kwargs,
            delimit_groups: false,
          ),
          **@kwargs,
          delimit_groups: false,
        )
      end

      should "properly remove parentheses" do
        assert_equal(
          ["aaa", "-", "bbb"],
          TagQuery.scan_recursive(
            "( aaa ) -( bbb )",
            **@kwargs,
            delimit_groups: false,
          ),
          **@kwargs,
          delimit_groups: false,
        )
      end
    end

    context "& not flattening" do
      should "work properly" do
        assert_equal(
          [["(", "aaa", ")"], ["-(", "bbb", ")"]],
          TagQuery.scan_recursive(
            "( aaa ) -( bbb )",
            **@kwargs,
            flatten: false,
          ),
          **@kwargs,
          flatten: false,
        )
        assert_equal(
          [["~(", "AAa", "-BBB*", ")"], "-bbb*"],
          TagQuery.scan_recursive(
            "~( AAa -BBB* ) -bbb*",
            **@kwargs,
            flatten: false,
          ),
          **@kwargs,
          flatten: false,
        )
      end

      should "properly strip prefixes" do
        assert_equal(
          [["(", "aaa", ")"], ["(", "bbb", ")"]],
          TagQuery.scan_recursive(
            "( aaa ) -( bbb )",
            **@kwargs,
            flatten: false,
            strip_prefixes: true,
          ),
          **@kwargs,
          flatten: false,
          strip_prefixes: true,
        )
        assert_equal(
          [["aaa"], ["bbb"]],
          TagQuery.scan_recursive(
            "( aaa ) -( bbb )",
            **@kwargs,
            delimit_groups: false,
            flatten: false,
            strip_prefixes: true,
          ),
          **@kwargs,
          delimit_groups: false,
          flatten: false,
          strip_prefixes: true,
        )
        assert_equal(
          [["aaa"], "-", ["bbb"]],
          TagQuery.scan_recursive(
            "( aaa ) -( bbb )",
            **@kwargs,
            delimit_groups: false,
            flatten: false,
          ),
          **@kwargs,
          delimit_groups: false,
          flatten: false,
        )
      end
    end

    context "& stripping duplicates" do
      setup do
        @kwargs[:strip_duplicates_at_level] = true
      end

      should "work on the same level of nesting" do
        assert_equal(
          ["aaa", "-bbb"],
          TagQuery.scan_recursive(
            "aaa aaa aaa -bbb",
            **@kwargs,
          ),
          **@kwargs,
        )
        assert_equal(
          %w[aaa bbb],
          TagQuery.scan_recursive(
            "~aaa -aaa ~aaa -bbb",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
        assert_equal(
          ["aaa", "~aaa", "-aaa", "-bbb"],
          TagQuery.scan_recursive(
            "aaa ~aaa -aaa ~aaa -bbb",
            **@kwargs,
          ),
          **@kwargs,
        )
        assert_equal(
          ["(", "aaa", "bbb", ")"],
          TagQuery.scan_recursive(
            "-( ~aaa ~aaa ~aaa -bbb )",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
      end

      should "work across multiple levels of nesting" do
        assert_equal(
          ["aaa", "(", "aaa", "bbb", ")"],
          TagQuery.scan_recursive(
            "~aaa -aaa -( ~aaa ~aaa ~aaa -bbb ) ~aaa -aaa",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
        assert_equal(
          ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")"],
          TagQuery.scan_recursive(
            "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
            **@kwargs,
          ),
          **@kwargs,
        )
        assert_equal(
          ["aaa", "(", "aaa", "bbb", ")"],
          TagQuery.scan_recursive(
            "~aaa -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
        assert_equal(
          ["aaa", "(", "(", "aaa", "bbb", ")", ")"],
          TagQuery.scan_recursive(
            "~aaa ( -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) ) aaa -aaa ~aaa",
            **@kwargs,
            strip_prefixes: true,
          ),
          **@kwargs,
          strip_prefixes: true,
        )
        assert_equal(
          ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")"],
          TagQuery.scan_recursive(
            "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) aaa -aaa ~aaa",
            **@kwargs,
          ),
          **@kwargs,
        )
        assert_equal(
          ["aaa", "-aaa", "~aaa", "(", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")", ")"],
          TagQuery.scan_recursive(
            "aaa -aaa ~aaa ( -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) ( -aaa ~aaa -aaa -bbb ) ) aaa -aaa ~aaa",
            **@kwargs,
          ),
          **@kwargs,
        )
      end
    end
  end
  # when "user", "-user", "~user" then add_to_query(type, :uploader_ids) { user_id_or_invalid(g2) }
  # when "user_id", "-user_id", "~user_id" then add_to_query(type, :uploader_ids) { g2.to_i }
  # when "approver", "-approver", "~approver"
  # when "commenter", "-commenter", "~commenter", "comm", "-comm", "~comm"
  # when "noter", "-noter", "~noter"
  # when "noteupdater", "-noteupdater", "~noteupdater"
  # when "pool", "-pool", "~pool"
  # when "set", "-set", "~set"
  # when "fav", "-fav", "~fav", "favoritedby", "-favoritedby", "~favoritedby"
  # when "md5" then q[:md5] = g2.downcase.split(",")[0..99]
  # when "rating", "-rating", "~rating" then add_to_query(type, :rating) { g2[0]&.downcase || "miss" }
  # when "locked", "-locked", "~locked"
  # when "ratinglocked" then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :rating }
  # when "notelocked" then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :note }
  # when "statuslocked" then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :status }
  # when "id", "-id", "~id" then add_to_query(type, :post_id) { ParseValue.range(g2) }
  # when "width", "-width", "~width" then add_to_query(type, :width) { ParseValue.range(g2) }
  # when "height", "-height", "~height" then add_to_query(type, :height) { ParseValue.range(g2) }
  # when "mpixels", "-mpixels", "~mpixels" then add_to_query(type, :mpixels) { ParseValue.range_fudged(g2, :float) }
  # when "ratio", "-ratio", "~ratio" then add_to_query(type, :ratio) { ParseValue.range(g2, :ratio) }
  # when "duration", "-duration", "~duration" then add_to_query(type, :duration) { ParseValue.range(g2, :float) }
  # when "score", "-score", "~score" then add_to_query(type, :score) { ParseValue.range(g2) }
  # when "favcount", "-favcount", "~favcount" then add_to_query(type, :fav_count) { ParseValue.range(g2) }
  # when "filesize", "-filesize", "~filesize" then add_to_query(type, :filesize) { ParseValue.range_fudged(g2, :filesize) }
  # when "change", "-change", "~change" then add_to_query(type, :change_seq) { ParseValue.range(g2) }
  # when "source", "-source", "~source"
  # when "date", "-date", "~date" then add_to_query(type, :date) { ParseValue.date_range(g2) }
  # when "age", "-age", "~age" then add_to_query(type, :age) { ParseValue.invert_range(ParseValue.range(g2, :age)) }
  # when "tagcount", "-tagcount", "~tagcount" then add_to_query(type, :post_tag_count) { ParseValue.range(g2) }
  # when /[-~]?(#{TagCategory::SHORT_NAME_REGEX})tags/
  # when "parent", "-parent", "~parent" then add_to_query(type, :parent_ids, any_none_key: :parent, value: g2) { g2.to_i }
  # when "child" then q[:child] = g2.downcase
  # when "randseed" then q[:random_seed] = g2.to_i
  # when "order" then q[:order] = g2.downcase
  # when "limit"
  # when "status"
  # when "-status"
  # when "filetype", "-filetype", "~filetype", "type", "-type", "~type" then add_to_query(type, :filetype) { g2.downcase }
  # when "description", "-description", "~description" then add_to_query(type, :description) { g2 }
  # when "note", "-note", "~note" then add_to_query(type, :note) { g2 }
  # when "delreason", "-delreason", "~delreason"
  MAPPING = {
    user: :uploader_ids,
    user_id: :uploader_ids,
    approver: :approver_ids,
    commenter: :commenter_ids,
    comm: :commenter_ids,
    noter: :noter_ids,
    noteupdater: :note_updater_ids,
    pool: :pool_ids,
    set: :set_ids,
    fav: :fav_ids,
    favoritedby: :fav_ids,
    md5: :md5,
    rating: :rating,
    locked: :locked,
    ratinglocked: :locked,
    notelocked: :locked,
    statuslocked: :locked,
    id: :post_id,
    width: :width,
    height: :height,
    mpixels: :mpixels,
    ratio: :ratio,
    duration: :duration,
    score: :score,
    favcount: :fav_count,
    filesize: :filesize,
    change: :change_seq,
    source: :sources,
    date: :date,
    tagcount: :post_tag_count,

    parent: :parent_ids,
    child: :child,
    randseed: :random_seed,
    order: :order,
    status: :status,
    filetype: :filetype,
    type: :filetype,
    description: :description,
    note: :note,
    delreason: :delreason,
    deletedby: :deleter,
    upvote: :upvote,
    votedup: :upvote,
    downvote: :downvote,
    voteddown: :downvote,
    voted: :voted,

  }.freeze
  ANY_KEY_MAPPING = {
    approver: :approver,
    commenter: :commenter,
    comm: :commenter,
    noter: :noter,
    pool: :pool,
    source: :source,
    parent: :parent,
  }.freeze
  FAV_SET_FAIL_VAL = -1
  # TODO: Add more test cases for group parsing
  # TODO: Add more test cases for metatag parsing
  context "Parsing a query:" do
    should "correctly handle up to 40 standard tags" do
      expected_result = {
        tags: {
          must: [],
          must_not: [],
          should: [],
        },
        show_deleted: false,
      }
      query = [*"a"..."u"].concat([*"a"..."u"].map { |e| "#{e}#{e}" }).each_with_index.map do |e, i|
        case i % 3
        when 0
          expected_result[:tags][:must] << e
          e
        when 1
          expected_result[:tags][:must_not] << e
          "-#{e}"
        when 2
          expected_result[:tags][:should] << e
          " ~#{e}"
        end
      end.join(" ")
      assert_equal(expected_result.freeze, TagQuery.new(query).q)
    end

    # TODO: Test invalid tag filtering when `TagQuery::SETTINGS[CHECK_TAG_VALIDITY]`, `TagQuery::SETTINGS[ERROR_ON_INVALID_TAG]`, & `TagQuery::SETTINGS[CATCH_INVALID_TAG]`align.
    # rubocop:disable Style/MultilineIfModifier
    should_eventually "not accept invalid standard tags" do
      # rubocop:enable Style/MultilineIfModifier
      # expected_result = {
      #   must: [],
      #   must_not: [],
      #   should: [],
      #   show_deleted: false,
      # }
      # query = ""
      # [*"a"..."u"].concat([*"a"..."u"].map { |e| "#{e}#{e}" }).each_with_index do |e, i|
      #   case i % 3
      #   when 0
      #     expected_result[:must] << e
      #     query += e
      #   when 1
      #     expected_result[:must_not] << e
      #     query += "-#{e}"
      #   when 2
      #     expected_result[:should] << e
      #     query += "~#{e}"
      #   end
      # end
      # assert_equal(expected_result, TagQuery.new(query).q)
    end if TagQuery::SETTINGS[:CHECK_TAG_VALIDITY]

    should "correctly handle wildcards" do
      create(:tag, name: "acb") # So `TagQuery.pull_wildcard_tags` works
      assert_equal(["acb"], TagQuery.new("a*b")[:tags][:should])
      assert_equal(["acb"], TagQuery.new("-a*b")[:tags][:must_not])
      # Single top level group
      assert_equal(["acb"], TagQuery.new("( a*b )")[:tags][:should])
    end

    context "W/ metatags:" do
      should "match w/ case insensitivity" do
        %w[id:2 Id:2 ID:2 iD:2].map { |e| TagQuery.new(e)[:post_id] }.all?(2)
      end

      # true -> true, everything else -> false
      should "parse boolean metatags correctly" do
        TagQuery::BOOLEAN_METATAGS.each do |e|
          assert_equal(true, TagQuery.new("#{e}:true")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:false")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:t")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:1")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:0")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:y")[e.downcase.to_sym])
          assert_equal(false, TagQuery.new("#{e}:literally_anything_else")[e.downcase.to_sym])
        end
      end

      # * Limited to 100 comma-separated entries
      should "parse md5 tags correctly" do
        assert_equal(["abc"], TagQuery.new("md5:abc")[:md5])
        arr = [*"aa".."zz"].freeze
        assert_equal(arr[0..99], TagQuery.new("md5:#{arr.join(',')}")[:md5])
      end

      should "correctly handle valid any/none values" do
        ANY_KEY_MAPPING.each_key do |e|
          assert_equal("any", TagQuery.new("#{e}:any")[ANY_KEY_MAPPING[e]])
          assert_equal("none", TagQuery.new("#{e}:none")[ANY_KEY_MAPPING[e]])
          assert_not_equal("diff", TagQuery.new("#{e}:diff")[ANY_KEY_MAPPING[e]])
        end
      end

      # `deletedby` & `delreason` also change `status` & `show_deleted` to deactivate deleted filtering
      should "correctly handle side-effects on deleted filtering" do
        %w[deletedby delreason].each do |x|
          ["#{x}:value", "#{x}:!404"].each do |y|
            result = TagQuery.new(y)
            assert_equal(true, result[:show_deleted])
            assert_equal("any", result[:status])
            assert_nil(result[:status_must_not])
            assert_not(result.hide_deleted_posts?)
            ["status:active #{y}", "#{y} status:active"].each do |z|
              result = TagQuery.new(z)
              assert_equal(true, result[:show_deleted])
              assert_equal("active", result[:status])
              assert_nil(result[:status_must_not])
              assert_not(result.hide_deleted_posts?)
            end
            ["-status:modqueue #{y}", "#{y} -status:modqueue"].each do |z|
              result = TagQuery.new(z)
              assert_equal(true, result[:show_deleted])
              assert_equal("modqueue", result[:status_must_not])
              assert_nil(result[:status])
              assert_not(result.hide_deleted_posts?)
            end
          end
        end
      end

      context "User-dependent:" do
        setup do
          @u_id = 101
          @a_id = 123
          @u_name = "#{@a_id}the_current_user".freeze
          @a_name = "#{@u_id}admin".freeze
          @user = create(:user, name: @u_name, enable_privacy_mode: true, id: @u_id, created_at: 4.days.ago)
          CurrentUser.user = @user
          # TODO: Change name to reflect role
          @admin_user = create(:moderator_user, name: @a_name, id: @a_id, created_at: 4.days.ago)
          @val_u = [@u_id].freeze
          @val_a = [@a_id].freeze
          @val_b = [-1].freeze
        end

        should "parse them correctly" do
          hash_u = { val: @val_u, id: @u_id, u_name: @u_name }.freeze
          hash_a = { val: @val_a, id: @a_id, u_name: @a_name }.freeze
          check_tags_on_users = ->(tags, users, bad_id = 404, bad_name = "nonexistent", label: "") do
            tags.each do |e|
              s = e.is_a?(Symbol) ? e : e.to_sym
              users.each do |u|
                # Doesn't validate id if using `!`
                # assert_equal(u.fetch(:id_failure_val, [bad_id].freeze), TagQuery.new("#{e}:!#{bad_id}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}")
                assert_equal(u.fetch(:failure_val, [bad_id].freeze), TagQuery.new("#{e}:!#{bad_id}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}")
                assert_equal(u.fetch(:failure_val, [-1]), TagQuery.new("#{e}:#{bad_name}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}")

                assert_equal(u[:val], TagQuery.new("#{e}:#{u[:u_name]}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}")
                assert_equal(u[:val], TagQuery.new("#{e}:!#{u[:id]}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}")

                # If leading w/ - but not entirely - a valid integral, will check user names
                assert_equal(u.fetch(:bang_val, [-1]), TagQuery.new("#{e}:!#{u[:u_name]}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}") unless u[:no_bang]

                # Can see other's values for this field?
                assert_equal(u.fetch(:o_val, [-1]), TagQuery.new("#{e}:#{u[:o_name]}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}") if u[:o_name]
                assert_equal(u.fetch(:o_val, [-1]), TagQuery.new("#{e}:!#{u[:o_id]}")[MAPPING[s]], "#{label}: #{e}: #{u[:u_name]}") if u[:o_id]
              end
            end
          end

          check_tags_on_users.call(
            %w[user approver commenter noter noteupdater deletedby].freeze,
            [
              hash_u.merge({ o_name: @a_name, o_id: @a_id, o_val: @val_a, bang_val: [-1].freeze }).freeze,
              hash_a.merge({ o_name: @u_name, o_id: @u_id, o_val: @val_u, bang_val: @val_b }).freeze,
            ].freeze,
            label: "Through check on standard tags",
          )

          check_tags_on_users.call(
            %w[upvote downvote voted votedup voteddown].freeze,
            [
              hash_u.merge({ failure_val: [@u_id].freeze, bang_val: [@u_id].freeze }).freeze,
              # hash_a.merge({ failure_val: [@a_id].freeze, bang_val: @val_b }).freeze,
            ].freeze,
            label: "Basic check on voting tags",
          )

          check_tags_on_users.call(
            %w[fav favoritedby].freeze,
            [hash_u.merge({ no_bang: true, failure_val: [FAV_SET_FAIL_VAL] }).freeze].freeze,
            FAV_SET_FAIL_VAL,
            label: "Basic-er check on fav tag",
          )

          check_tags_on_users.call(
            %w[set].freeze,
            [hash_u.merge({ no_bang: true, failure_val: [FAV_SET_FAIL_VAL].freeze, val: [FAV_SET_FAIL_VAL].freeze }).freeze].freeze,
            FAV_SET_FAIL_VAL,
            label: "Basic-est check on set tag",
          )

          assert_equal(@val_u, TagQuery.new("user_id:#{@u_id}")[MAPPING[:user_id]])
          assert_equal(@val_a, TagQuery.new("user_id:#{@a_id}")[MAPPING[:user_id]])

          # NOTE: User id handling will partially convert strings leading w/ valid numbers (e.g. `user_id:123string` -> `123`).
          # Unintentional as it may be, this ensures that behavior remains consistent.
          assert_equal(@val_a, TagQuery.new("user_id:#{@u_name}")[MAPPING[:user_id]])
          assert_equal(@val_u, TagQuery.new("user_id:#{@a_name}")[MAPPING[:user_id]])
        end

        context "Votes:" do
          setup do
            @tags = %i[upvote downvote voted votedup voteddown].freeze
          end

          should "let users can see their own votes" do
            @tags.each do |x|
              assert_equal(@val_u, TagQuery.new("#{x}:#{@u_name}")[MAPPING[x]])
              assert_equal(@val_u, TagQuery.new("#{x}:!#{@u_id}")[MAPPING[x]])
            end
          end

          should "not let normal users see other user's votes" do
            @tags.each do |x|
              assert_equal(@val_u, TagQuery.new("#{x}:#{@a_name}")[MAPPING[x]])
              assert_equal(@val_u, TagQuery.new("#{x}:!#{@a_id}")[MAPPING[x]])
            end
          end

          should "let moderators & higher see other user's votes" do
            CurrentUser.user = @admin_user
            # Check user change worked
            assert_equal(@val_a, TagQuery.new("upvote:#{@a_name}")[MAPPING[:upvote]])
            @tags.each do |x|
              assert_equal(@val_u, TagQuery.new("#{x}:#{@u_name}")[MAPPING[x]])
              assert_equal(@val_u, TagQuery.new("#{x}:!#{@u_id}")[MAPPING[x]])
            end
          end
        end

        should "parse 'set' metatags correctly" do
          # Users can see public sets
          pub_set = create(:post_set, is_public: true, creator: @admin_user)
          assert_equal([pub_set.id], TagQuery.new("set:#{pub_set.id}")[MAPPING[:set]])
          assert_equal([pub_set.id], TagQuery.new("set:#{pub_set.shortname}")[MAPPING[:set]])

          # Users can see their own sets
          u_set = create(:post_set, creator: @user, is_public: false)
          assert_equal([u_set.id], TagQuery.new("set:#{u_set.id}")[MAPPING[:set]])
          assert_equal([u_set.id], TagQuery.new("set:#{u_set.shortname}")[MAPPING[:set]])

          # Normal users can't see other user's private sets
          a_set = create(:post_set, creator: @admin_user, is_public: false)
          # assert_equal([-1], TagQuery.new("set:#{a_set.id}")[MAPPING[:set]])
          # assert_equal([-1], TagQuery.new("set:#{a_set.shortname}")[MAPPING[:set]])
          assert_raises(User::PrivilegeError) { TagQuery.new("set:#{a_set.id}")[MAPPING[:set]] }
          assert_raises(User::PrivilegeError) { TagQuery.new("set:#{a_set.shortname}")[MAPPING[:set]] }

          # Moderators & higher can see other user's private sets
          CurrentUser.user = @admin_user
          assert_equal([u_set.id], TagQuery.new("set:#{u_set.id}")[MAPPING[:set]])
          assert_equal([u_set.id], TagQuery.new("set:#{u_set.shortname}")[MAPPING[:set]])
        end

        should "parse fav/favoritedby metatags correctly" do
          %i[fav favoritedby].each do |x|
            # Users can see public favs
            assert_equal(@val_a, TagQuery.new("#{x}:#{@a_name}")[MAPPING[x]])
            assert_equal(@val_a, TagQuery.new("#{x}:!#{@a_id}")[MAPPING[x]])

            # Users can see their own favs
            assert_equal(@val_u, TagQuery.new("#{x}:#{@u_name}")[MAPPING[x]])
            assert_equal(@val_u, TagQuery.new("#{x}:!#{@u_id}")[MAPPING[x]])

            # Normal users can't see other user's private favs
            @admin_user.update(enable_privacy_mode: true)
            assert_raises(Favorite::HiddenError) { TagQuery.new("#{x}:#{@a_name}") }
            @admin_user.update(enable_privacy_mode: false)

            # Moderators & higher can see other user's private favs
            CurrentUser.user = @admin_user
            assert_equal(@val_u, TagQuery.new("#{x}:#{@u_name}")[MAPPING[x]])
            CurrentUser.user = @user
          end
        end
      end

      context "using range" do
        should "parse them correctly" do
          # TODO: Add COUNT_METATAGS & others
          assert_equal([[:between, 1, 2]], TagQuery.new("id:1..2")[:post_id])
          assert_equal([[:gt, 2]], TagQuery.new("id:>2")[:post_id])
          assert_equal([[:gte, 2]], TagQuery.new("id:>=2")[:post_id])
          assert_equal([[:lt, 3]], TagQuery.new("id:<3")[:post_id])
          assert_equal([[:lte, 3]], TagQuery.new("id:<=3")[:post_id])
        end
      end
    end

    # should "correctly handle valid quoted metatags" do
    #   user = create(:user)
    #   Danbooru.config.expects(:is_unlimited_tag?).with(anything).times(3).returns(false)
    #   query = TagQuery.new('user:hash description:" a description w/ some stuff" delreason:"a good one"')
    #   assert_equal()
    # end
  end

  # TODO: expand to all valid candidates
  should "allow multiple types for a metatag in a single query" do
    query = TagQuery.new("id:1 -id:2 ~id:3 id:4 -id:5 ~id:6")
    assert_equal([[:eq, 1], [:eq, 4]], query[:post_id])
    assert_equal([[:eq, 2], [:eq, 5]], query[:post_id_must_not])
    assert_equal([[:eq, 3], [:eq, 6]], query[:post_id_should])
  end

  should "fail for more than 40 tags" do
    assert_raise(TagQuery::CountExceededError) do
      TagQuery.new("rating:s width:10 height:10 user:bob #{[*'aa'..'zz'].join(' ')}")
    end
  end

  # TODO: Figure out tests for sorting tags in scan_recursive
  # TODO: Figure out tests for distributing prefixes in scan_recursive

  context "While recursively scanning" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
      # non-top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "a ( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
      # mixed level query
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, v| "#{v.even? ? 'a ' : ''}( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
    end

    should "not fail for less than or equal to #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      TagQuery.scan_recursive((0...(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
      # non-top level
      TagQuery.scan_recursive((0...(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "a ( #{accumulator} )" }, error_on_depth_exceeded: true)
      # mixed level query
      TagQuery.scan_recursive((0...(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, v| "#{v.even? ? 'a ' : ''}( #{accumulator} )" }, error_on_depth_exceeded: true)
    end
  end

  context "While hoisting through the constructor" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.new("aaa #{(0..(TagQuery::DEPTH_LIMIT - 1)).inject('limit:10') { |accumulator, _| "( #{accumulator} )" }}", error_on_depth_exceeded: true)
      end
    end
    should "not fail for less than or equal to #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      TagQuery.new("aaa #{(0...(TagQuery::DEPTH_LIMIT - 1)).inject('limit:10') { |accumulator, _| "( #{accumulator} )" }}", error_on_depth_exceeded: true)
    end
  end

  context "While unpacking a search of a single group through the constructor" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.new((0..(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
    end

    should "not fail for less than or equal to #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      TagQuery.new((0...(TagQuery::DEPTH_LIMIT - 1)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
    end
  end

  RESPECT_ALL_QUOTED_METATAGS = false
  # TODO: Add tests for block variables
  # TODO: Add tests for prepend_prefix
  # TODO: Add tests for non-spaced group when RESPECT_ALL_QUOTED_METATAGS is true
  context "While recursively searching metatags" do
    should "find top-level instances of specified metatags" do
      assert_equal(["metatags:50", "another:metatag"], TagQuery.scan_metatags("some tags and metatags:50 and another:metatag and a failed:match", "metatags", "another"))
    end

    should "not find false positives in quoted metatags" do
      assert_equal(["matching:metatag", "another:metatag"], TagQuery.scan_metatags("some tags and a matching:metatag and a quoted_metatag:\"don't match metatags:this but do match \" another:metatag then a failed:match", "metatags", "another", "matching"))
    end

    should "find top-level instances of a quoted metatag" do
      assert_equal(["matching:metatag", "quoted_metatag:\"don't match metatags:this but do match \"", "another:metatag"], TagQuery.scan_metatags("some tags and a matching:metatag and a quoted_metatag:\"don't match metatags:this but do match \" another:metatag then a failed:match", "metatags", "another", "matching", "quoted_metatag"))
    end

    should "find all metatags" do
      assert_equal(["metatags:50", "another:metatag", "failed:match"], TagQuery.scan_metatags("some tags and metatags:50 and another:metatag and a failed:match", "\\w+"))
      assert_equal(["metatags:50", "another:metatag", "failed:match"], TagQuery.scan_metatags("some tags and metatags:50 and another:metatag and a failed:match", :any))
      assert_equal(["matching:metatag", 'quoted_metatag:"don\'t match metatags:this but do match "', "another:metatag", "failed:match"], TagQuery.scan_metatags('some tags and a matching:metatag and a quoted_metatag:"don\'t match metatags:this but do match " another:metatag then a failed:match', "\\w+"))
      assert_equal(["matching:metatag", 'quoted_metatag:"don\'t match metatags:this but do match "', "another:metatag", "failed:match"], TagQuery.scan_metatags('some tags and a matching:metatag and a quoted_metatag:"don\'t match metatags:this but do match " another:metatag then a failed:match', :any))
    end

    should "#{RESPECT_ALL_QUOTED_METATAGS ? '' : 'not '}respect quoted metatags not followed by either whitespace or the end of input" do
      input_str = 'some tags and a matching:metatag and a quoted_metatag:"don\'t match metatags:this but do match "another:metatag then a failed:match'
      if RESPECT_ALL_QUOTED_METATAGS
        assert_equal(["matching:metatag", 'quoted_metatag:"don\'t match metatags:this but do match "', "another:metatag", "failed:match"], TagQuery.scan_metatags(input_str, :any))
        assert_equal(["matching:metatag", 'quoted_metatag:"don\'t match metatags:this but do match "', "another:metatag"], TagQuery.scan_metatags(input_str, "metatags", "another", "matching", "quoted_metatag"))
        assert_equal(["matching:metatag", "another:metatag"], TagQuery.scan_metatags(input_str, "metatags", "another", "matching"))
      else
        assert_equal(["matching:metatag", 'quoted_metatag:"don\'t', "metatags:this", "failed:match"], TagQuery.scan_metatags(input_str, :any))
        assert_equal(["matching:metatag", "quoted_metatag:\"don't", "metatags:this"], TagQuery.scan_metatags(input_str, "metatags", "another", "matching", "quoted_metatag"))
        input_str = 'some tags and a matching:metatag and a quoted_metatag:"do match metatags:this but don\'t match "another:metatag then a failed:match'
        assert_equal(["matching:metatag", "metatags:this"], TagQuery.scan_metatags(input_str, "metatags", "another", "matching"))
        # Don't match metatags w/ non-word characters
        assert_equal(["matching:metatag", "metatags:this"], TagQuery.scan_metatags(input_str, "metatags", "another", "matching"))
        assert_equal(["matching:metatag", 'quoted_metatag:"do', "metatags:this", "failed:match"], TagQuery.scan_metatags(input_str, :any))
      end
    end
  end

  context "When determining whether or not to hide deleted posts" do
    context "before parsing" do
      should "work with a string" do
        assert(TagQuery.should_hide_deleted_posts?("aaa bbb"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb status:deleted"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb deletedby:someone"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb delreason:something"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb -status:active"))
        assert(TagQuery.should_hide_deleted_posts?("aaa bbb status:modqueue"))
        assert(TagQuery.should_hide_deleted_posts?("( aaa bbb )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb status:any )"))
        assert(TagQuery.should_hide_deleted_posts?("( aaa ( bbb ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa status:any ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa deletedby:someone ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa delreason:something ) status:pending )"))
        assert(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa ) status:pending )"))
        assert(TagQuery.should_hide_deleted_posts?("aaa ( bbb status:modqueue )"))
      end

      should "work with an array" do
        kwargs = { hoisted_metatags: nil }.freeze
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb status:deleted", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb deletedby:someone", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb delreason:something", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb -status:active", **kwargs)))
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb status:modqueue", **kwargs)))
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("( aaa bbb )", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb status:any )", **kwargs)))
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("( aaa ( bbb ) )", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa status:any ) )", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa deletedby:someone ) )", **kwargs)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa delreason:something ) status:pending )", **kwargs)))
      end
    end

    should "work after parsing" do
      assert(TagQuery.new("aaa bbb").hide_deleted_posts?)
      assert_not(TagQuery.new("aaa bbb status:deleted").hide_deleted_posts?)
      assert_not(TagQuery.new("aaa bbb deletedby:someone").hide_deleted_posts?)
      assert_not(TagQuery.new("aaa bbb delreason:something status:pending").hide_deleted_posts?)
      assert(TagQuery.new("( aaa bbb )").hide_deleted_posts?)
      assert(TagQuery.new("aaa ( bbb status:any )").hide_deleted_posts?)
      assert(TagQuery.new("( aaa ( bbb ) )").hide_deleted_posts?)
      assert(TagQuery.new("aaa ( bbb ( aaa status:any ) )").hide_deleted_posts?)
      assert(TagQuery.new("aaa ( bbb ( aaa deletedby:someone ) )").hide_deleted_posts?)
      assert(TagQuery.new("aaa ( bbb ( aaa delreason:something ) status:pending )").hide_deleted_posts?)
    end
  end

  # TODO: Figure out all potential edge cases
  # should_eventually "quickly & correctly identify if query contains groups" do
  #   # Just a group
  #   # Just a prefixed group
  #   # a group preceded by normal tags
  #   # a group succeeded by normal tags
  #   # a group preceded & succeeded by normal tags
  #   # a prefixed group preceded by normal tags
  #   # a prefixed group succeeded by normal tags
  #   # a prefixed group preceded & succeeded by normal tags
  #   # a group preceded by metatags
  #   # a group succeeded by metatags
  #   # a group preceded & succeeded by metatags
  #   # a prefixed group preceded by metatags
  #   # a prefixed group succeeded by metatags
  #   # a prefixed group preceded & succeeded by metatags
  #   # a group preceded by prefixed metatags
  #   # a group succeeded by prefixed metatags
  #   # a group preceded & succeeded by prefixed metatags
  #   # a prefixed group preceded by prefixed metatags
  #   # a prefixed group succeeded by prefixed metatags
  #   # a prefixed group preceded & succeeded by prefixed metatags
  #   # a group preceded by quoted metatags
  #   # a group succeeded by quoted metatags
  #   # a group preceded & succeeded by quoted metatags
  #   # a prefixed group preceded by quoted metatags
  #   # a prefixed group succeeded by quoted metatags
  #   # a prefixed group preceded & succeeded by quoted metatags
  #   # a group preceded by quoted prefixed metatags
  #   # a group succeeded by quoted prefixed metatags
  #   # a group preceded & succeeded by quoted prefixed metatags
  #   # a prefixed group preceded by quoted prefixed metatags
  #   # a prefixed group succeeded by quoted prefixed metatags
  #   # a prefixed group preceded & succeeded by quoted prefixed metatags
  #   # a false group with start by quoted metatags
  #   # a false group end by quoted metatags
  #   # a false false group with start & end by quoted metatags
  #   # a false prefixed group with start by quoted metatags
  #   # a false prefixed group end by quoted metatags
  #   # a false false prefixed group with start & end by quoted metatags
  #   # a false group with start by quoted prefixed metatags
  #   # a false group end by quoted prefixed metatags
  #   # a false false group with start & end by quoted prefixed metatags
  #   # a false prefixed group with start by quoted prefixed metatags
  #   # a false prefixed group end by quoted prefixed metatags
  #   # a false false prefixed group with start & end by quoted prefixed metatags
  #   # a false group with start by quoted metatags w/ accompanying true group delimiters
  #   # a false group end by quoted metatags w/ accompanying true group delimiters
  #   # a false false group with start & end by quoted metatags w/ accompanying true group delimiters
  #   # a false prefixed group with start by quoted metatags w/ accompanying true group delimiters
  #   # a false prefixed group end by quoted metatags w/ accompanying true group delimiters
  #   # a false false prefixed group with start & end by quoted metatags w/ accompanying true group delimiters
  #   # a false group with start by quoted prefixed metatags w/ accompanying true group delimiters
  #   # a false group end by quoted prefixed metatags w/ accompanying true group delimiters
  #   # a false false group with start & end by quoted prefixed metatags w/ accompanying true group delimiters
  #   # a false prefixed group with start by quoted prefixed metatags w/ accompanying true group delimiters
  #   # a false prefixed group end by quoted prefixed metatags w/ accompanying true group delimiters
  #   # a false false prefixed group with start & end by quoted prefixed metatags w/ accompanying true group delimiters
  # end
end
