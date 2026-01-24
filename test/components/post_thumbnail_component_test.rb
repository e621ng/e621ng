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

  # ========================================
  # Basic Rendering Tests
  # ========================================

  test "renders with basic options" do
    as(@user) do
      component = PostThumbnailComponent.new(post: @post, stats: true)
      render component

      assert_select "article.thumbnail[data-id='#{@post.id}']"
      assert_select "article.thumbnail.rating-safe"
      assert_select "img[alt='post ##{@post.id}']"
      assert_select ".thm-desc .thm-score"
      assert_select ".thm-desc .thm-favorites"
      assert_select ".thm-desc .thm-comments"
      assert_select ".thm-desc .thm-rating"
    end
  end

  test "works with Draper-decorated post objects" do
    as(@user) do
      # Create a mock decorator that responds to :object
      decorated_post = Struct.new(:object).new(@post)

      component = PostThumbnailComponent.new(post: decorated_post, stats: true)

      render component

      assert_select "article.thumbnail[data-id='#{@post.id}']"
    end
  end

  test "works with anonymous user" do
    post = nil
    as(@user) do
      post = create(:post)
    end

    # Switch to anonymous user context
    old_user = CurrentUser.user
    CurrentUser.user = User.anonymous

    component = PostThumbnailComponent.new(post: post)
    render component

    assert_select "article.thumbnail"
  ensure
    CurrentUser.user = old_user
  end

  # ========================================
  # render? Method Logic Tests
  # ========================================

  test "does not render for nil post" do
    as(@user) do
      component = PostThumbnailComponent.new(post: nil)
      render component

      assert_select "article", count: 0
    end
  end

  test "does not render for loginblocked post" do
    as(@user) do
      post = create(:post)
      post.stubs(:loginblocked?).returns(true)

      component = PostThumbnailComponent.new(post: post)
      render component

      assert_select "article", count: 0
    end
  end

  test "does not render for safeblocked post" do
    as(@user) do
      post = create(:post)
      post.stubs(:safeblocked?).returns(true)

      component = PostThumbnailComponent.new(post: post)
      render component

      assert_select "article", count: 0
    end
  end

  test "does not render hidden deleted post" do
    as(@user) do
      post = create(:post, is_deleted: true, tag_string: "tag1")
      TagQuery.stubs(:should_hide_deleted_posts?).returns(true)

      component = PostThumbnailComponent.new(post: post, tags: "tag1")
      render component

      assert_select "article", count: 0
    end
  end

  test "renders deleted post when show_deleted is true" do
    as(@user) do
      post = create(:post, is_deleted: true)

      component = PostThumbnailComponent.new(post: post, show_deleted: true)
      render component

      assert_select "article.thumbnail.deleted"
    end
  end

  # ========================================
  # CSS Class Tests
  # ========================================

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

  test "includes has-parent class when post has parent" do
    as(@user) do
      parent = create(:post)
      child = create(:post, parent_id: parent.id)

      component = PostThumbnailComponent.new(post: child)
      render component

      assert_select "article.thumbnail.has-parent"
    end
  end

  test "includes has-children class when post has children" do
    as(@user) do
      parent = create(:post)
      parent.stubs(:has_visible_children?).returns(true)

      component = PostThumbnailComponent.new(post: parent)
      render component

      assert_select "article.thumbnail.has-children"
    end
  end

  test "includes blacklistable class by default" do
    as(@user) do
      post = create(:post)
      component = PostThumbnailComponent.new(post: post)

      render component

      assert_select "article.thumbnail.blacklistable"
    end
  end

  test "excludes blacklistable class when no_blacklist is true" do
    as(@user) do
      post = create(:post)
      component = PostThumbnailComponent.new(post: post, no_blacklist: true)

      render component

      assert_select "article.thumbnail" do |elements|
        assert_not elements.first[:class].include?("blacklistable")
      end
    end
  end

  test "includes all status classes for post with multiple flags" do
    as(@user) do
      post = create(:post, is_pending: true, is_flagged: true, is_deleted: true)

      component = PostThumbnailComponent.new(post: post, show_deleted: true)
      render component

      assert_select "article.thumbnail.pending.flagged.deleted"
    end
  end

  # ========================================
  # Score Display Tests
  # ========================================

  test "displays positive score with correct styling" do
    as(@user) do
      positive_post = create(:post, score: 10)
      component = PostThumbnailComponent.new(post: positive_post, stats: true)

      render component

      assert_select ".thm-score.thm-score-positive"
    end
  end

  test "displays negative score correctly" do
    as(@user) do
      post = create(:post, score: -15)
      component = PostThumbnailComponent.new(post: post, stats: true)

      render component

      assert_select ".thm-score.thm-score-negative", text: /15/
    end
  end

  test "displays zero score as neutral" do
    as(@user) do
      post = create(:post, score: 0)
      component = PostThumbnailComponent.new(post: post, stats: true)

      render component

      assert_select ".thm-score.thm-score-neutral", text: "0"
    end
  end

  test "displays large scores in k format" do
    as(@user) do
      post = create(:post, score: 1500)
      component = PostThumbnailComponent.new(post: post, stats: true)

      render component

      assert_select ".thm-score", text: /1\.5k/
    end
  end

  test "handles nil score" do
    as(@user) do
      post = create(:post)
      post.stubs(:score).returns(nil)
      component = PostThumbnailComponent.new(post: post, stats: true)

      render component

      assert_select ".thm-score", text: "0"
    end
  end

  # ========================================
  # Stats Visibility Tests
  # ========================================

  test "hides stats when stats: false" do
    as(@user) do
      post = create(:post)
      component = PostThumbnailComponent.new(post: post, stats: false)

      render component

      assert_select ".thm-desc", count: 0
      assert_select "article.thumbnail.no-stats"
    end
  end

  test "uses user preference for stats display" do
    as(@user) do
      @user.stubs(:show_post_statistics?).returns(false)
      post = create(:post)

      component = PostThumbnailComponent.new(post: post)
      render component

      assert_select ".thm-desc", count: 0
    end
  end

  # ========================================
  # Link Parameter Tests
  # ========================================

  test "includes tags in link parameters" do
    as(@user) do
      component = PostThumbnailComponent.new(post: @post, tags: "test_search")

      render component

      assert_select "a[href*='q=test_search']"
    end
  end

  test "includes pool_id in link parameters" do
    as(@user) do
      post = create(:post)
      component = PostThumbnailComponent.new(post: post, pool_id: 123)

      render component

      assert_select "a[href*='pool_id=123']"
    end
  end

  test "includes post_set_id in link parameters" do
    as(@user) do
      post = create(:post)
      component = PostThumbnailComponent.new(post: post, post_set_id: 456)

      render component

      assert_select "a[href*='post_set_id=456']"
    end
  end

  test "uses custom link_target when provided" do
    as(@user) do
      post = create(:post)
      other_post = create(:post)

      component = PostThumbnailComponent.new(post: post, link_target: other_post)
      render component

      assert_select "a[href*='#{other_post.id}']"
    end
  end

  # ========================================
  # Image Source Tests
  # ========================================

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

  # ========================================
  # Deleted Post Image Rendering Tests
  # ========================================

  test "janitor can see deleted post images" do
    janitor = create(:janitor_user)
    as(janitor) do
      post = create(:post, is_deleted: true)

      component = PostThumbnailComponent.new(post: post, show_deleted: true)
      render component

      assert_select "img"
    end
  end

  test "regular user cannot see deleted post images" do
    as(@user) do
      post = create(:post, is_deleted: true)

      component = PostThumbnailComponent.new(post: post, show_deleted: true)
      render component

      assert_select "picture", count: 0
      assert_select "img", count: 0
    end
  end

  # ========================================
  # Pool Display Tests
  # ========================================

  test "displays pool name when pool option provided" do
    as(@user) do
      post = create(:post)
      pool = create(:pool, name: "Test_Pool")

      component = PostThumbnailComponent.new(post: post, pool: pool)
      render component

      assert_select ".thm-extra .pool-link", text: /Test Pool/
      assert_select ".thm-desc", count: 0 # Stats disabled when pool present
    end
  end

  test "truncates long pool names" do
    as(@user) do
      post = create(:post)
      pool = create(:pool, name: "A" * 100)

      component = PostThumbnailComponent.new(post: post, pool: pool)
      render component

      assert_select ".thm-extra .pool-link" do |elements|
        assert elements.first.text.length <= 80
      end
    end
  end

  # ========================================
  # IQDB Similarity Display Tests
  # ========================================

  test "displays similarity score when provided" do
    as(@user) do
      post = create(:post, file_size: 500_000, file_ext: "jpg", image_width: 800, image_height: 600)

      component = PostThumbnailComponent.new(post: post, similarity: 95.7)
      render component

      assert_select ".thm-extra", text: /Similarity: 96/
      assert_select ".thm-extra", text: /JPG/
      assert_select ".thm-extra", text: /800x600/
    end
  end

  # ========================================
  # Tooltip Tests
  # ========================================

  test "includes basic post info in tooltip" do
    as(@user) do
      post = create(:post, rating: "s", score: 10)
      component = PostThumbnailComponent.new(post: post)

      render component

      assert_select "a[data-hover-text*='Rating: s']"
      assert_select "a[data-hover-text*='Score: 10']"
      assert_select "a[data-hover-text*='ID: #{post.id}']"
    end
  end

  test "includes janitor info in tooltip for janitors" do
    janitor = create(:janitor_user)
    as(janitor) do
      uploader = create(:user, name: "test_uploader")
      post = create(:post, uploader: uploader)

      component = PostThumbnailComponent.new(post: post)
      render component

      assert_select "a[data-hover-text*='Uploader: test_uploader']"
    end
  end
end
