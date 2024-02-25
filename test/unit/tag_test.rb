# frozen_string_literal: true

require "test_helper"

class TagTest < ActiveSupport::TestCase
  setup do
    @janitor = create(:janitor_user)
    CurrentUser.user = @janitor
  end

  context "A tag category fetcher" do
    should "fetch for a single tag" do
      create(:artist_tag, name: "test")
      assert_equal(Tag.categories.artist, Tag.category_for("test"))
    end

    should "fetch for a single tag with strange markup" do
      create(:artist_tag, name: "!@ab")
      assert_equal(Tag.categories.artist, Tag.category_for("!@ab"))
    end

    should "return general for a tag that doesn't exist" do
      assert_equal(Tag.categories.general, Tag.category_for("missing"))
    end

    should "fetch for multiple tags" do
      create(:artist_tag, name: "aaa")
      create(:copyright_tag, name: "bbb")
      categories = Tag.categories_for(%w(aaa bbb ccc))
      assert_equal(Tag.categories.artist, categories["aaa"])
      assert_equal(Tag.categories.copyright, categories["bbb"])
      assert_nil(categories["ccc"])
    end
  end

  context "A tag category mapping" do
    should "exist" do
      assert_nothing_raised {Tag.categories}
    end

    should "have convenience methods for the four main categories" do
      assert_equal(0, Tag.categories.general)
      assert_equal(1, Tag.categories.artist)
      assert_equal(3, Tag.categories.copyright)
      assert_equal(4, Tag.categories.character)
      assert_equal(7, Tag.categories.meta)
    end

    should "have a regular expression for matching category names and shortcuts" do
      regexp = Tag.categories.regexp

      assert_match(regexp, "artist")
      assert_match(regexp, "art")
      assert_match(regexp, "copyright")
      assert_match(regexp, "copy")
      assert_match(regexp, "co")
      assert_match(regexp, "character")
      assert_match(regexp, "char")
      assert_match(regexp, "ch")
      assert_match(regexp, "meta")
      assert_no_match(regexp, "c")
      assert_no_match(regexp, "woodle")
    end

    should "map a category name to its value" do
      assert_equal(0, Tag.categories.value_for("general"))
      assert_equal(0, Tag.categories.value_for("gen"))
      assert_equal(1, Tag.categories.value_for("artist"))
      assert_equal(1, Tag.categories.value_for("art"))
      assert_equal(7, Tag.categories.value_for("meta"))
      assert_equal(0, Tag.categories.value_for("unknown"))
    end
  end

  context "A tag" do
    should "know its category name" do
      @tag = create(:artist_tag)
      assert_equal("Artist", @tag.category_name)
    end

    should "reset its category after updating" do
      tag = create(:artist_tag)
      assert_equal(Tag.categories.artist, Cache.fetch("tc:#{tag.name}"))

      tag.update_attribute(:category, Tag.categories.copyright)
      assert_equal(Tag.categories.copyright, Cache.fetch("tc:#{tag.name}"))
    end

    context "not be settable to an invalid category" do
      should validate_inclusion_of(:category).in_array(TagCategory::CATEGORY_IDS)
    end
  end

  context "A tag" do
    should "be found when one exists" do
      tag = create(:tag)
      assert_difference("Tag.count", 0) do
        Tag.find_or_create_by_name(tag.name)
      end
    end

    should "change the type for an existing tag" do
      tag = create(:tag)
      assert_difference("Tag.count", 0) do
        assert_equal(Tag.categories.general, tag.category)
        Tag.find_or_create_by_name("artist:#{tag.name}")
        tag.reload
        assert_equal(Tag.categories.artist, tag.category)
      end
    end

    should "not change the category is the tag is locked" do
      tag = create(:tag, is_locked: true)
      assert_equal(true, tag.is_locked?)
      Tag.find_or_create_by_name("artist:#{tag.name}")
      tag.reload
      assert_equal(0, tag.category)
    end

    should "not change category when the tag is too large to be changed by a janitor" do
      tag = create(:tag, post_count: 1001)
      Tag.find_or_create_by_name("artist:#{tag.name}", creator: @janitor)

      assert_equal(0, tag.reload.category)
    end

    should "not change category when the tag is too large to be changed by a member" do
      tag = create(:tag, post_count: 51)
      Tag.find_or_create_by_name("artist:#{tag.name}", creator: create(:member_user))

      assert_equal(0, tag.reload.category)
    end

    should "update post tag counts when the category is changed" do
      post = create(:post, tag_string: "test")
      assert_equal(1, post.tag_count_general)
      assert_equal(0, post.tag_count_character)

      tag = Tag.find_by_normalized_name('test')
      with_inline_jobs { tag.update_attribute(:category, 4) }
      assert_equal tag.errors.full_messages, []
      post.reload
      assert_equal(0, post.tag_count_general)
      assert_equal(1, post.tag_count_character)
    end

    should "be created when one doesn't exist" do
      assert_difference("Tag.count", 1) do
        tag = Tag.find_or_create_by_name("hoge")
        assert_equal("hoge", tag.name)
        assert_equal(Tag.categories.general, tag.category)
      end
    end

    should "be created with the type when one doesn't exist" do
      assert_difference("Tag.count", 1) do
        tag = Tag.find_or_create_by_name("artist:hoge")
        assert_equal("hoge", tag.name)
        assert_equal(Tag.categories.artist, tag.category)
      end
    end

    context "during name validation" do
      # tags with spaces or uppercase are allowed because they are normalized
      # to lowercase with underscores.
      should allow_value(" foo ").for(:name).on(:create)
      should allow_value("foo bar").for(:name).on(:create)
      should allow_value("FOO").for(:name).on(:create)

      should_not allow_value("").for(:name).on(:create)
      should_not allow_value("___").for(:name).on(:create)
      %w|- ~ + _ ` ( ) { } [ ] /|.each do |x|
        should_not allow_value("#{x}foo").for(:name).on(:create)
      end
      should_not allow_value("foo_").for(:name).on(:create)
      should_not allow_value("foo__bar").for(:name).on(:create)
      should_not allow_value("foo*bar").for(:name).on(:create)
      should_not allow_value("foo,bar").for(:name).on(:create)
      should_not allow_value("foo\abar").for(:name).on(:create)
      should_not allow_value("café").for(:name).on(:create)
      should_not allow_value("東方").for(:name).on(:create)
      should_not allow_value("FAV:blah").for(:name).on(:create)

      metatags = TagQuery::METATAGS + TagCategory::MAPPING.keys
      metatags.each do |metatag|
        should_not allow_value("#{metatag}:foo").for(:name).on(:create)
      end
    end
  end

  context "A tag with a negative post count" do
    should "be fixed" do
      reset_post_index
      tag = create(:tag, name: "touhou", post_count: -10)
      post = create(:post, tag_string: "touhou")

      Tag.clean_up_negative_post_counts!
      assert_equal(1, tag.reload.post_count)
    end
  end
end
