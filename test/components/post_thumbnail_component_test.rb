# frozen_string_literal: true

require "test_helper"

class PostThumbnailComponentTest < ActionView::TestCase
  include FactoryBot::Syntax::Methods

  def setup
    @user = create(:user)
    as(@user) do
      @post = create(:post,
                     rating: "s",
                     score: 5,
                     fav_count: 3,
                     tag_string: "tag1 tag2",
                     is_pending: false,
                     is_flagged: false,
                     is_deleted: false,
                     parent_id: nil,
                     has_active_children: false)
    end
  end

  test "renders with basic options" do
    as(@user) do
      component = PostThumbnailComponent.new(post: @post, stats: true)
      render component

      assert_select "article#post_#{@post.id}.thumbnail"
      assert_select "article.thumbnail.rating-safe"
      assert_select "img[alt='post ##{@post.id}']"
      assert_select ".desc .score"
      assert_select ".desc .favorites"
      assert_select ".desc .comments"
      assert_select ".desc .rating"
    end
  end

  test "does not render for nil post" do
    as(@user) do
      component = PostThumbnailComponent.new(post: nil)
      render component

      assert_select "article", count: 0
    end
  end

  test "includes correct CSS classes for pending post" do
    as(@user) do
      pending_post = create(:post, is_pending: true)
      component = PostThumbnailComponent.new(post: pending_post)

      render component

      assert_select "article.thumbnail.pending"
    end
  end

  test "includes correct CSS classes for flagged post" do
    as(@user) do
      flagged_post = create(:post, is_flagged: true)
      component = PostThumbnailComponent.new(post: flagged_post)

      render component

      assert_select "article.thumbnail.flagged"
    end
  end

  test "includes correct CSS classes for different ratings" do
    as(@user) do
      safe_post = create(:post, rating: "s")
      questionable_post = create(:post, rating: "q")
      explicit_post = create(:post, rating: "e")

      render PostThumbnailComponent.new(post: safe_post)
      assert_select "article.thumbnail.rating-safe"

      render PostThumbnailComponent.new(post: questionable_post)
      assert_select "article.thumbnail.rating-questionable"

      render PostThumbnailComponent.new(post: explicit_post)
      assert_select "article.thumbnail.rating-explicit"
    end
  end

  test "displays score with correct styling" do
    as(@user) do
      positive_post = create(:post, score: 10)
      component = PostThumbnailComponent.new(post: positive_post, stats: true)

      render component

      assert_select ".score.score-positive"
    end
  end

  test "includes tags in link parameters" do
    as(@user) do
      component = PostThumbnailComponent.new(post: @post, tags: "test_search")

      render component

      assert_select "a[href*='q=test_search']"
    end
  end

  test "includes WebP source when enabled" do
    as(@user) do
      # Skip this test if WebP is disabled by default
      skip "WebP is disabled in test environment" unless Danbooru.config.webp_previews_enabled?

      component = PostThumbnailComponent.new(post: @post)
      render component
      assert_select 'source[type="image/webp"]'
    end
  end

  test "includes JPEG source always" do
    as(@user) do
      component = PostThumbnailComponent.new(post: @post)
      render component
      assert_select 'source[type="image/jpeg"]'
    end
  end

  test "works with Draper-decorated post objects" do
    as(@user) do
      # Create a mock decorator that responds to :object
      decorated_post = Struct.new(:object).new(@post)

      component = PostThumbnailComponent.new(post: decorated_post, stats: true)

      render component

      assert_select "article#post_#{@post.id}.thumbnail"
    end
  end
end
