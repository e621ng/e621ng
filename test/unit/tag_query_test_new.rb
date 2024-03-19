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
end
