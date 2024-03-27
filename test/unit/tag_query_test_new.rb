# frozen_string_literal: true

require "test_helper"

class TagQueryTestNew < ActiveSupport::TestCase
  should "fail at a group depth of greater than 10" do
    assert_raise(TagQueryNew::MaxGroupDepthExceededError) do
      TagQueryNew.new("( 1 ( 2 ( 3 ( 4 ( 5 ( 6 ( 7 ( 8 ( 9 ( 10 ( 11 ( ) ) ) ) ) ) ) ) ) ) ) )")
    end
  end

  should "fail at token count greater than 40 in a single group" do
    assert_raise(TagQueryNew::MaxTokensAchievedInGroupError) do
      TagQueryNew.new("( rating:s width:10 height:10 user:bob #{[*'aa'..'zz'].join(' ')} )")
    end
  end

  should "fail when a group is left open" do
    assert_raise(TagQueryNew::MaxTokensAchievedInGroupError) do
      TagQueryNew.new("( tag ( tag2 )")
    end
  end

  should "properly parse a simple query" do
    query = TagQuery.new("female male duo")
    assert_equal(%w[female male duo], query[:tokens])
  end

  should "properly parse groups within a query" do
    query = TagQuery.new("rating:s ( female ~ male ) ( solo ~ duo )")
    assert_equal(["rating:s", "__0", "__1"], query[:tokens])
    assert_equal([{ tokens: ["female", "~", "male"], groups: [] }, { tokens: ["solo", "~", "duo"], groups: [] }], query[:groups])
  end

  should "properly parse groups within groups" do
    query = TagQuery.new("( female ( male solo ) )")
    assert_equal(["__0"], query[:tokens])
    assert_equal([{ tokens: %w[female __0], groups: [{ tokens: %w[male solo], groups: [] }] }], query[:groups])
  end

  should "properly assign negation symbol as its own token" do
    query = TagQuery.new("-male")
    assert_equal(["-", "male"], query[:tokens])
  end

  should "not assign a hyphen within a tag its own symbol" do
    query = TagQuery.new("test-tag")
    assert_equal(["test-tag"], query[:tokens])
  end

  should "not assign a group to a tag that contains parentheses" do
    query = TagQuery.new("test_(tag)")
    assert_equal(["test_(tag)"], query[:tokens])
  end

  should "allow text within quotes to have spaces" do
    query = TagQuery.new("description:\"A test description that contains spaces.\"")
    assert_equal(["description:\"A test description that contains spaces.\""], query[:tokens])
  end
end
