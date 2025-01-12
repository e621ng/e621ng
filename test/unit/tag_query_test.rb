# frozen_string_literal: true

require "test_helper"

class TagQueryTest < ActiveSupport::TestCase
  should "scan a query" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan("~AAa -BBB* -bbb*"))
    # Order is now preserved
    assert_equal(["aaa", 'test:"with spaces"', "def"], TagQuery.scan('aaa test:"with spaces" def'))
    # assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan('aaa test:"with spaces" def'))
  end

  context "While scanning for searching" do
    should "behave identically to the non-search variant when no groups exist" do
      assert_equal(%w[aaa bbb], TagQuery.scan_search("aaa bbb"))
      assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan_search("~AAa -BBB* -bbb*"))
      # Order is now preserved
      assert_equal(["aaa", 'test:"with spaces"', "def"], TagQuery.scan_search('aaa test:"with spaces" def'))
      # assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan_search('aaa test:"with spaces" def'))
    end
    should "pull out top-level group w/o a modifier" do
      assert_equal(%w[aaa bbb], TagQuery.scan_search("( aaa bbb )"))
    end
    should "not pull out top-level group w/ a modifier" do
      assert_equal(["-( aaa bbb )"], TagQuery.scan_search("-( aaa bbb )"))
    end
    should "properly handle simple groups" do
      assert_equal(["( aaa )", "-( bbb )"], TagQuery.scan_search("( aaa ) -( bbb )"))
      assert_equal(["~( AAa -BBB* )", "-bbb*"], TagQuery.scan_search("~( AAa -BBB* ) -bbb*"))
    end
    should "hoist metatags" do
      assert_equal(["order:random", "limit:50", "( aaa )", "randseed:123", "-( bbb )"], TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"))
      assert_equal("random", TagQuery.new("( order:random aaa limit:50 ) -( bbb randseed:123 )")[:order])
      assert_equal(123, TagQuery.new("( order:random aaa limit:50 ) -( bbb randseed:123 )")[:random_seed])
    end
  end

  should "fetch nested metatag" do
    assert_equal("50", TagQuery.fetch_metatag("( order:random aaa limit:50 ) -( bbb randseed:123 )", "limit"))
    assert_equal("50", TagQuery.fetch_metatag(TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"), "limit"))
  end

  should "fetch nested tags" do
    assert_equal(["aaa"], TagQuery.fetch_tags(TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"), "aaa"))
    assert_equal(%w[aaa bbb], TagQuery.fetch_tags(TagQuery.scan_search("( order:random aaa limit:50 ) -( bbb randseed:123 )"), "aaa", "bbb"))
  end

  # TODO: Reorganize w/ context
  should "scan a grouped query recursively" do
    p = {
      strip_duplicates_at_level: false,
      delimit_groups: true,
      flatten: true,
      strip_prefixes: false,
      sort_at_level: false,
      normalize_at_level: false,
      error_on_depth_exceeded: false,
    }
    assert_equal(["(", "aaa", "bbb", ")"], TagQuery.scan_recursive("( aaa bbb )"))
    assert_equal(
      ["(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["-(", "~aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        **p,
      ),
      **p,
    )
    assert_equal(
      ["-(", "~aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        **p,
      ),
      **p,
    )
    assert_equal(
      [["(", "aaa", ")"], ["-(", "bbb", ")"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        **p,
        flatten: false,
        strip_prefixes: false,
      ),
      **p,
      flatten: false,
      strip_prefixes: false,
    )
    assert_equal(
      [["(", "aaa", ")"], ["(", "bbb", ")"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        **p,
        flatten: false,
        strip_prefixes: true,
      ),
      **p,
      flatten: false,
      strip_prefixes: true,
    )
    assert_equal(
      [["aaa"], ["bbb"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        **p,
        delimit_groups: false,
        flatten: false,
        strip_prefixes: true,
      ),
      **p,
      delimit_groups: false,
      flatten: false,
      strip_prefixes: true,
    )
    assert_equal(
      [["aaa"], "-", ["bbb"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        **p,
        delimit_groups: false,
        flatten: false,
      ),
      **p,
      delimit_groups: false,
      flatten: false,
    )
    assert_equal(
      ["aaa", "-", "bbb"],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        **p,
        delimit_groups: false,
      ),
      **p,
      delimit_groups: false,
    )
    assert_equal(
      ["~(", "AAa", "-BBB*", ")", "-bbb*"],
      TagQuery.scan_recursive(
        "~( AAa -BBB* ) -bbb*",
        **p,
      ),
      **p,
    )
    assert_equal(
      [["~(", "AAa", "-BBB*", ")"], "-bbb*"],
      TagQuery.scan_recursive(
        "~( AAa -BBB* ) -bbb*",
        **p,
        flatten: false,
      ),
      **p,
      flatten: false,
    )
    assert_equal(
      ["aaa", 'test:"with spaces"', "def"],
      TagQuery.scan_recursive('aaa test:"with spaces" def'),
    )
  end

  should "recursively scan and strip duplicates" do
    p = {
      strip_duplicates_at_level: false,
      delimit_groups: true,
      flatten: true,
      strip_prefixes: false,
      sort_at_level: false,
      normalize_at_level: false,
      error_on_depth_exceeded: false,
    }
    p[:strip_duplicates_at_level] = true
    assert_equal(
      ["aaa", "-bbb"],
      TagQuery.scan_recursive(
        "aaa aaa aaa -bbb",
        **p,
      ),
      **p,
    )
    assert_equal(
      %w[aaa bbb],
      TagQuery.scan_recursive(
        "~aaa -aaa ~aaa -bbb",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["aaa", "~aaa", "-aaa", "-bbb"],
      TagQuery.scan_recursive(
        "aaa ~aaa -aaa ~aaa -bbb",
        **p,
      ),
      **p,
    )
    assert_equal(
      ["(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa ~aaa ~aaa -bbb )",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["aaa", "(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "~aaa -aaa -( ~aaa ~aaa ~aaa -bbb ) ~aaa -aaa",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
        **p,
      ),
      **p,
    )
    assert_equal(
      ["aaa", "(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "~aaa -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["aaa", "(", "(", "aaa", "bbb", ")", ")"],
      TagQuery.scan_recursive(
        "~aaa ( -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) ) aaa -aaa ~aaa",
        **p,
        strip_prefixes: true,
      ),
      **p,
      strip_prefixes: true,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) aaa -aaa ~aaa",
        **p,
      ),
      **p,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "(", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa ( -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) ( -aaa ~aaa -aaa -bbb ) ) aaa -aaa ~aaa",
        **p,
      ),
      **p,
    )
  end

  should "not strip out valid characters when scanning" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    assert_equal(%w[aaa bbb], TagQuery.scan_search("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan_search("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
  end

  should "parse a query" do
    create(:tag, name: "acb")
    assert_equal(["abc"], TagQuery.new("md5:abc")[:md5])
    assert_equal([[:between, 1, 2]], TagQuery.new("id:1..2")[:post_id])
    assert_equal([[:gt, 2]], TagQuery.new("id:>2")[:post_id])
    assert_equal([[:gte, 2]], TagQuery.new("id:>=2")[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("id:<3")[:post_id])
    assert_equal([[:lte, 3]], TagQuery.new("id:<=3")[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("ID:<3")[:post_id])
    assert_equal([[:lte, 3]], TagQuery.new("ID:<=3")[:post_id])
    assert_equal(["acb"], TagQuery.new("a*b")[:tags][:should])
    # Single top level group
    assert_equal(["acb"], TagQuery.new("( a*b )")[:tags][:should])
    # TODO: Add more test cases for groups
  end

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

  context "While fetching tags" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags([(0..(TagQuery::DEPTH_LIMIT)).inject("aaa") { |accumulator, _| "( #{accumulator} )" }], "aaa", error_on_depth_exceeded: true)
      end
      # non-top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags(["a", "( #{(0..(TagQuery::DEPTH_LIMIT)).inject('aaa') { |accumulator, _| "a ( #{accumulator} )" }} )"], "aaa", error_on_depth_exceeded: true)
      end
      # mixed level query
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.fetch_tags(["a", "( #{(0..(TagQuery::DEPTH_LIMIT)).inject('aaa') { |accumulator, v| "#{v.even? ? 'a ' : ''}( #{accumulator} )" }} )"], "aaa", error_on_depth_exceeded: true)
      end
    end
  end

  context "While recursively scanning" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      # top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
      # non-top level
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT)).inject("rating:s") { |accumulator, _| "a ( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
      # mixed level query
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.scan_recursive((0..(TagQuery::DEPTH_LIMIT)).inject("rating:s") { |accumulator, v| "#{v.even? ? 'a ' : ''}( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
    end
  end

  context "While hoisting through the constructor" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.new("aaa #{(0..(TagQuery::DEPTH_LIMIT)).inject('limit:10') { |accumulator, _| "( #{accumulator} )" }}", error_on_depth_exceeded: true)
      end
    end
  end

  context "While unpacking a search of a single group through the constructor" do
    should "fail for more than #{TagQuery::DEPTH_LIMIT} levels of group nesting" do
      assert_raise(TagQuery::DepthExceededError) do
        TagQuery.new((0..(TagQuery::DEPTH_LIMIT)).inject("rating:s") { |accumulator, _| "( #{accumulator} )" }, error_on_depth_exceeded: true)
      end
    end
  end

  context "While recursively searching metatags" do
    should "find top-level instances of specified metatags" do
      assert_equal(["metatags:50", "another:metatag"], TagQuery.recurse_through_metatags("some tags and metatags:50 and another:metatag and a failed:match", "metatags", "another"))
    end
    should "not find false positives in quoted metatags & handle a tag w/o a space after a quoted metatag" do
      assert_equal(["matching:metatag", "another:metatag"], TagQuery.recurse_through_metatags("some tags and a matching:metatag and a quoted_metatag:\"don't match metatags:this but match \"another:metatag then a failed:match", "metatags", "another", "matching"))
    end
    should "find top-level instances of a quoted metatag & handle a tag w/o a space after a quoted metatag" do
      assert_equal(["matching:metatag", "quoted_metatag:\"don't match metatags:this but match \"", "another:metatag"], TagQuery.recurse_through_metatags("some tags and a matching:metatag and a quoted_metatag:\"don't match metatags:this but match \"another:metatag then a failed:match", "metatags", "another", "matching", "quoted_metatag"))
    end
  end

  # TODO: Once the predictive method can handle status overwriting correctly, add assertions to test
  context "When determining whether or not to hide deleted posts" do
    context "before parsing" do
      should "work with a string" do
        assert(TagQuery.should_hide_deleted_posts?("aaa bbb"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb status:deleted"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa bbb deletedby:someone"))
        assert(TagQuery.should_hide_deleted_posts?("( aaa bbb )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb status:any )"))
        assert(TagQuery.should_hide_deleted_posts?("( aaa ( bbb ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa status:any ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa deletedby:someone ) )"))
        assert_not(TagQuery.should_hide_deleted_posts?("aaa ( bbb ( aaa delreason:something ) status:pending )"))
      end
      should "work with an array" do
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb status:deleted", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb deletedby:someone", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa bbb delreason:something status:pending", hoisted_metatags: nil)))
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("( aaa bbb )", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb status:any )", hoisted_metatags: nil)))
        assert(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("( aaa ( bbb ) )", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa status:any ) )", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa  deletedby:someone ) )", hoisted_metatags: nil)))
        assert_not(TagQuery.should_hide_deleted_posts?(TagQuery.scan_search("aaa ( bbb ( aaa delreason:something ) status:pending )", hoisted_metatags: nil)))
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
end
