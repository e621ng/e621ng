# frozen_string_literal: true

require "test_helper"

class UserBlocksControllerTest < ActionDispatch::IntegrationTest
  context "The user blocks controller" do
    setup do
      @user = create(:user)
      @user2 = create(:user)
      @admin = create(:admin_user)
      CurrentUser.user = @user
    end

    context "index action" do
      should "allow user to view their own blocks" do
        get_auth user_blocks_path(@user), @user
        assert_response :success
      end

      should "not allow users to view other users blocks" do
        get_auth user_blocks_path(@user2), @user
        assert_response :forbidden
      end

      should "allow admins to view other users blocks" do
        get_auth user_blocks_path(@user), @admin
        assert_response :success
      end
    end

    context "create action" do
      context "as a member" do
        should "allow blocking other members" do
          post_auth user_blocks_path(@user), @user, params: { user_block: { target_id: @user2.id, disable_messages: true }, format: :json }
          assert_response :success

          assert @user.is_blocking_messages_from?(@user2)
        end

        should "not allow blocking messages from staff" do
          post_auth user_blocks_path(@user), @user, params: { user_block: { target_id: @admin.id, disable_messages: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "base"), "You cannot block messages from staff members")

          assert_not @user.is_blocking_messages_from?(@user2)
        end

        should "not allow blocking self" do
          post_auth user_blocks_path(@user), @user, params: { user_block: { target_id: @user.id, hide_comments: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "base"), "You cannot block yourself")

          assert_not @admin.is_blocking_comments_from?(@admin)
        end

        should "not allow creating duplicate blocks" do
          create(:user_block, user: @user, target: @user2)
          post_auth user_blocks_path(@user), @user, params: { user_block: { target_id: @user2.id, hide_comments: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "target_id"), "has already been taken")
        end

        should "not allow creating invalid blocks" do
          post_auth user_blocks_path(@user), @user, params: { user_block: { hide_comments: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "target"), "must exist")
        end

        should "not allow creating blocks for others" do
          post_auth user_blocks_path(@user), @user2, params: { user_block: { target_id: @user2.id, hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_not @user.is_blocking_comments_from?(@user2)
        end
      end

      context "as an admin" do
        should "allow blocking other members" do
          post_auth user_blocks_path(@admin), @admin, params: { user_block: { target_id: @user.id, hide_comments: true }, format: :json }
          assert_response :success

          assert @admin.is_blocking_comments_from?(@user)
          assert_not @admin.is_blocking_messages_from?(@user)
        end

        should "not allow blocking messages" do
          post_auth user_blocks_path(@admin), @admin, params: { user_block: { target_id: @user.id, disable_messages: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "base"), "You cannot block messages")

          assert_not @admin.is_blocking_messages_from?(@user)
        end

        should "not allow creating blocks for others" do
          post_auth user_blocks_path(@user), @admin, params: { user_block: { target_id: @admin.id, hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_not @user.is_blocking_comments_from?(@admin)
        end
      end
    end

    context "update action" do
      context "as a member" do
        setup do
          @block = create(:user_block, user: @user, target: @user2)
        end

        should "allow updating" do
          assert_not @user.is_blocking_messages_from?(@user2)

          put_auth user_block_path(@user, @block), @user, params: { user_block: { disable_messages: true }, format: :json }
          assert_response :success

          assert @user.is_blocking_messages_from?(@user2)
        end

        should "not allow blocking messages from staff" do
          block = create(:user_block, user: @user, target: @admin)
          put_auth user_block_path(@user, block), @user, params: { user_block: { disable_messages: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "base"), "You cannot block messages from staff members")

          assert_not @user.is_blocking_messages_from?(@admin)
        end

        should "not allow editing target" do
          put_auth user_block_path(@user, @block), @user, params: { user_block: { target_id: @admin.id, hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_equal(@user2, @block.reload.target)
        end

        should "not allow editing others blocks" do
          put_auth user_block_path(@user, @block), @user2, params: { user_block: { hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_not @user.is_blocking_comments_from?(@user2)
        end
      end

      context "as an admin" do
        setup do
          @block = create(:user_block, user: @admin, target: @user)
        end

        should "allow updating" do
          assert_not @admin.is_blocking_comments_from?(@user)

          put_auth user_block_path(@admin, @block), @admin, params: { user_block: { hide_comments: true }, format: :json }
          assert_response :success

          assert @admin.is_blocking_comments_from?(@user)
        end

        should "not allow blocking messages" do
          put_auth user_block_path(@admin, @block), @admin, params: { user_block: { disable_messages: true }, format: :json }
          assert_response :unprocessable_entity
          assert_includes(@response.parsed_body.dig("errors", "base"), "You cannot block messages")

          assert_not @admin.is_blocking_messages_from?(@user)
        end

        should "not allow editing target" do
          put_auth user_block_path(@admin, @block), @admin, params: { user_block: { target_id: @user2.id, hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_equal(@user, @block.reload.target)
        end

        should "not allow editing others blocks" do
          block = create(:user_block, user: @user, target: @user2)
          put_auth user_block_path(@user, block), @admin, params: { user_block: { hide_comments: true }, format: :json }
          assert_response :forbidden

          assert_not @user.is_blocking_comments_from?(@user2)
        end
      end
    end

    context "delete action" do
      context "as a member" do
        setup do
          @block = create(:user_block, user: @user, target: @user2)
        end

        should "work" do
          delete_auth user_block_path(@user, @block), @user, params: { format: :json }
          assert_response :success

          assert_raises(ActiveRecord::RecordNotFound) do
            @block.reload
          end
        end

        should "not allow deleting others blocks" do
          delete_auth user_block_path(@user, @block), @user2, params: { format: :json }
          assert_response :forbidden

          assert_nothing_raised do
            @block.reload
          end
        end
      end

      context "as an admin" do
        setup do
          @block = create(:user_block, user: @admin, target: @user)
        end

        should "work" do
          delete_auth user_block_path(@admin, @block), @admin, params: { format: :json }
          assert_response :success

          assert_raises(ActiveRecord::RecordNotFound) do
            @block.reload
          end
        end

        should "not allow deleting others blocks" do
          block = create(:user_block, user: @user, target: @user2)
          delete_auth user_block_path(@user, block), @admin, params: { format: :json }
          assert_response :forbidden

          assert_nothing_raised do
            @block.reload
          end
        end
      end
    end
  end
end
