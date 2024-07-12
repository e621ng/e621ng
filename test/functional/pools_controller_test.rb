# frozen_string_literal: true

require "test_helper"

class PoolsControllerTest < ActionDispatch::IntegrationTest
  context "The pools controller" do
    setup do
      travel_to(1.month.ago) do
        @user = create(:user)
        @mod = create(:moderator_user)
      end
      as(@user) do
        @post = create(:post)
        @pool = create(:pool)
      end
    end

    context "index action" do
      should "list all pools" do
        get pools_path
        assert_response :success
      end

      should "list all pools (with search)" do
        get pools_path, params: {:search => {:name_matches => @pool.name}}
        assert_response :success
      end
    end

    context "show action" do
      should "render" do
        get pool_path(@pool)
        assert_response :success
      end
    end

    context "gallery action" do
      should "render" do
        get gallery_pools_path
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_pool_path, @user
        assert_response :success
      end
    end

    context "create action" do
      should "create a pool" do
        assert_difference("Pool.count", 1) do
          post_auth pools_path, @user, params: {:pool => {:name => "xxx", :description => "abc"}}
        end
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_pool_path(@pool), @user
        assert_response :success
      end
    end

    context "update action" do
      should "update a pool" do
        put_auth pool_path(@pool), @user, params: { pool: { name: "xyz", post_ids: [@post.id] }}
        assert_equal("xyz", @pool.reload.name)
        assert_equal([@post.id], @pool.post_ids)
      end

      should "not allow updating unpermitted attributes" do
        put_auth pool_path(@pool), @user, params: { pool: { post_count: -42 }}
        assert_equal(0, @pool.post_count)
      end
    end

    context "destroy action" do
      should "destroy a pool" do
        delete_auth pool_path(@pool), @mod
        assert_raises(ActiveRecord::RecordNotFound) do
          @pool.reload
        end
      end
    end

    context "revert action" do
      setup do
        as(@user) do
          @post_2 = create(:post)
          @pool = create(:pool, post_ids: [@post.id])
        end
        as(@user, "1.2.3.4") do
          @pool.update(post_ids: [@post.id, @post_2.id])
        end
      end

      should "revert to a previous version" do
        @pool.reload
        version = @pool.versions.first
        assert_equal([@post.id], version.post_ids)
        put_auth revert_pool_path(@pool), @mod, params: {:version_id => version.id}
        @pool.reload
        assert_equal([@post.id], @pool.post_ids)
      end

      should "not allow reverting to a previous version of another pool" do
        as(@user) do
          @pool2 = create(:pool)
        end
        put_auth revert_pool_path(@pool), @user, params: {:version_id => @pool2.versions.first.id }
        @pool.reload
        assert_not_equal(@pool.name, @pool2.name)
        assert_response :missing
      end
    end

    should "render the order action" do
      get_auth edit_pool_order_path(@pool), @user
      assert_response :success
    end
  end
end
