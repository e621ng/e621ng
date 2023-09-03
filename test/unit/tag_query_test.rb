require "test_helper"

class TagQueryTest < ActiveSupport::TestCase
  should "scan a query" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan("~AAa -BBB* -bbb*"))
    assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan('aaa test:"with spaces" def'))
  end

  should "not strip out valid characters when scanning" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
  end

  should "parse a query" do
    create(:tag, name: "acb")
    assert_equal(["abc"], TagQuery.new("md5:abc")[:md5])
    assert_equal([:between, 1, 2], TagQuery.new("id:1..2")[:post_id])
    assert_equal([:gt, 2], TagQuery.new("id:>2")[:post_id])
    assert_equal([:lt, 3], TagQuery.new("id:<3")[:post_id])
    assert_equal([:lt, 3], TagQuery.new("ID:<3")[:post_id])
    assert_equal(["acb"], TagQuery.new("a*b")[:tags][:should])
  end

  should "fail for more than 40 tags" do
    assert_raise(TagQuery::CountExceededError) do
      TagQuery.new("rating:s width:10 height:10 user:bob #{[*'aa'..'zz'].join(' ')}")
    end
  end
end
