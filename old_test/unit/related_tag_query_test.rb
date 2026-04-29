# frozen_string_literal: true

require "test_helper"

class RelatedTagQueryTest < ActiveSupport::TestCase
  setup do
    user = create(:user)
    CurrentUser.user = user
  end

  context "a related tag query without a category constraint" do
    setup do
      @post_1 = create(:post, tag_string: "aaa bbb")
      @post_2 = create(:post, tag_string: "aaa bbb ccc")
    end

    context "for a tag that already exists" do
      setup do
        Tag.find_by_name("aaa").update_related
        @query = RelatedTagQuery.new(query: "aaa")
      end

      should "work" do
        assert_equal(["aaa", "bbb", "ccc"], @query.tags)
      end

      should "render the json" do
        assert_equal([
          { name: "aaa", category_id: 0 },
          { name: "bbb", category_id: 0 },
          { name: "ccc", category_id: 0 },
        ].to_json, @query.to_json)
      end
    end

    context "for a tag that doesn't exist" do
      setup do
        @query = RelatedTagQuery.new(query: "zzz")
      end

      should "work" do
        assert_equal([], @query.tags)
      end
    end

    context "for an aliased tag" do
      setup do
        @ta = create(:tag_alias, antecedent_name: "xyz", consequent_name: "aaa")
        @wp = create(:wiki_page, title: "aaa", body: "blah [[foo|blah]] [[FOO]] [[bar]] blah")
        @query = RelatedTagQuery.new(query: "xyz")

        Tag.find_by_name("aaa").update_related
      end

      should "take related tags from the consequent tag" do
        assert_equal(%w[aaa bbb ccc], @query.tags)
      end
    end

    context "for a pattern search" do
      setup do
        @query = RelatedTagQuery.new(query: "a*")
      end

      should "work" do
        assert_equal(["aaa"], @query.tags)
      end
    end

    context "for a tag with a wiki page" do
      setup do
        @wiki_page = create(:wiki_page, :title => "aaa", body: "[[bbb]] [[ccc]]")
        @query = RelatedTagQuery.new(query: "aaa")
      end
    end
  end

  context "a related tag query with a category constraint" do
    setup do
      @post_1 = create(:post, tag_string: "aaa bbb")
      @post_2 = create(:post, tag_string: "aaa art:ccc")
      @post_3 = create(:post, tag_string: "aaa copy:ddd")
      @query = RelatedTagQuery.new(query: "aaa", category_id: Tag.categories.artist)
    end

    should "find the related tags" do
      assert_equal(%w(ccc), @query.tags)
    end
  end
end
