# frozen_string_literal: true

require "test_helper"

class PostFlagReasonsControllerTest < ActionDispatch::IntegrationTest
  context "The post flag reasons controller" do
    setup do
      @admin = create(:admin_user)
      @user = create(:user)
      CurrentUser.user = @admin
      @reason = create(:post_flag_reason)
    end

    context "index action" do
      should "render" do
        get post_flag_reasons_path
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_post_flag_reason_path, @admin
        assert_response :success
      end
    end

    context "create action" do
      should "work" do
        assert_difference(%w[PostFlagReason.count ModAction.count], 1) do
          post_auth post_flag_reasons_path, @admin, params: { post_flag_reason: { name: "test", reason: "test", text: "test" } }
        end

        assert_equal("post_flag_reason_create", ModAction.last.action)
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_post_flag_reason_path(@reason), @admin
        assert_response :success
      end
    end

    context "update action" do
      should "work" do
        assert_difference("ModAction.count", 1) do
          put_auth post_flag_reason_path(@reason), @admin, params: { post_flag_reason: { name: "xxx" } }
          assert_redirected_to(post_flag_reasons_path)
        end
        assert_equal("post_flag_reason_update", ModAction.last.action)
        assert_equal("xxx", @reason.reload.name)
      end
    end

    context "destroy action" do
      should "work" do
        assert_difference({ "PostFlagReason.count" => -1, "ModAction.count" => 1 }) do
          delete_auth post_flag_reason_path(@reason), @admin
          assert_redirected_to(post_flag_reasons_path)
        end
        assert_raises(ActiveRecord::RecordNotFound) { @reason.reload }
        assert_equal("post_flag_reason_delete", ModAction.last.action)
      end
    end

    context "order action" do
      should "render" do
        get_auth order_post_flag_reasons_path, @admin
        assert_response :success
      end
    end

    context "reorder action" do
      setup do
        count = PostFlagReason.count
        if count < 3
          create_list(:post_flag_reason, 3 - count)
        end
      end

      should "work" do
        data = PostFlagReason.pluck(:id, :order).map { |id, order| { id: id, order: order } }
        swap = data[0][:order]
        data[0][:order] = data[1][:order]
        data[1][:order] = swap
        assert_difference("ModAction.count", 1) do
          post_auth reorder_post_flag_reasons_path, @admin, params: { _json: data, format: :json }
          assert_response :success
        end
        assert_equal("post_flag_reasons_reorder", ModAction.last.action)
        assert_equal(data[0][:order], PostFlagReason.find(data[0][:id]).order)
        assert_equal(data[1][:order], PostFlagReason.find(data[1][:id]).order)
      end

      should "not allow duplicate orders" do
        data = PostFlagReason.pluck(:id, :order).map { |id, order| { id: id, order: order } }
        data[1][:order] = data[0][:order]
        post_auth reorder_post_flag_reasons_path, @admin, params: { _json: data, format: :json }
        assert_response 422
      end
    end
  end
end
