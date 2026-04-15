# frozen_string_literal: true

require "test_helper"

class PostSetsControllerSyncTest < ActionDispatch::IntegrationTest
  context "PostSetsController sync behavior" do
    setup do
      @user = create(:user)
      @post = create(:post)
      @set = create(:post_set, creator: @user)
    end

    should "sync inline when adding a single post" do
      PostSetPostsSyncJob.expects(:perform_later).never
      post_auth add_posts_post_set_path(@set), @user, params: { post_ids: [@post.id] }
      assert_response :redirect
      @post.reload
      assert @post.belongs_to_post_set(@set)
    end

    should "enqueue job when adding multiple posts" do
      posts = create_list(:post, 3)
      PostSetPostsSyncJob.expects(:perform_later).once
      post_auth add_posts_post_set_path(@set), @user, params: { post_ids: posts.map(&:id) }
      assert_response :redirect
    end

    should "update_posts sync inline when a single change" do
      PostSetPostsSyncJob.expects(:perform_later).never
      post_auth update_posts_post_set_path(@set), @user, params: { post_set: { post_ids_string: @post.id.to_s } }
      assert_response :redirect
      @post.reload
      assert @post.belongs_to_post_set(@set), "post should belong to set after single-change update_posts"
      @set.reload
      assert_equal [@post.id], @set.post_ids
    end

    should "update_posts enqueue job when multiple changes" do
      p1 = create(:post)
      p2 = create(:post)
      PostSetPostsSyncJob.expects(:perform_later).once
      post_auth update_posts_post_set_path(@set), @user, params: { post_set: { post_ids_string: [p1.id, p2.id].join(" ") } }
      assert_response :redirect
      @set.reload
      assert_equal [p1.id, p2.id].sort, @set.post_ids.sort
    end
  end
end
