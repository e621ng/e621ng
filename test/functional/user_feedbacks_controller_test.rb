# frozen_string_literal: true

require "test_helper"

class UserFeedbacksControllerTest < ActionDispatch::IntegrationTest
  context "The user feedbacks controller" do
    setup do
      @user = create(:user)
      @critic = create(:moderator_user)
      @mod = create(:moderator_user)
    end

    context "new action" do
      should "render" do
        get_auth new_user_feedback_path, @critic, params: { user_feedback: { user_id: @user.id } }
        assert_response :success
      end
    end

    context "edit action" do
      setup do
        as(@critic) do
          @user_feedback = create(:user_feedback, user: @user)
        end
      end

      should "render" do
        get_auth edit_user_feedback_path(@user_feedback), @critic
        assert_response :success
      end
    end

    context "index action" do
      setup do
        as(@critic) do
          @user_feedback = create(:user_feedback, user: @user)
        end
      end

      should "render" do
        get_auth user_feedbacks_path, @user
        assert_response :success
      end

      context "with search parameters" do
        should "render" do
          get_auth user_feedbacks_path, @critic, params: { search: { user_id: @user.id } }
          assert_response :success
        end
      end
    end

    context "create action" do
      should "create a new feedback" do
        assert_difference([-> { UserFeedback.count }, -> { Dmail.count }], 1) do
          post_auth user_feedbacks_path, @critic, params: { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } }
        end
      end
    end

    context "update action" do
      should "update the feedback" do
        as(@critic) do
          @feedback = create(:user_feedback, user: @user, category: "negative")
        end

        assert_no_difference(-> { Dmail.count }) do
          put_auth user_feedback_path(@feedback), @critic, params: { id: @feedback.id, user_feedback: { category: "positive" } }
        end

        assert_redirected_to(@feedback)
        assert("positive", @feedback.reload.category)
        assert_match(/created a/, Dmail.last.body)
      end

      should "send a new dmail" do
        as(@critic) do
          @feedback = create(:user_feedback, user: @user, category: "negative")
        end
        assert_difference(-> { Dmail.count }, 1) do
          put_auth user_feedback_path(@feedback), @critic, params: { id: @feedback.id, user_feedback: { body: "changed", send_update_dmail: true } }
        end
        assert_match(/updated a/, Dmail.last.body)
      end
    end

    context "destroy action" do
      setup do
        as(@critic) do
          @user_feedback = create(:user_feedback, user: @user)
        end
      end

      should "delete a feedback" do
        assert_difference(-> { UserFeedback.count }, -1) do
          delete_auth user_feedback_path(@user_feedback), @critic
        end
      end

      context "by a moderator" do
        should "allow deleting feedbacks given to other users" do
          assert_difference(-> { UserFeedback.count }, -1) do
            delete_auth user_feedback_path(@user_feedback), @mod
          end
        end

        should "not allow deleting feedbacks given to themselves" do
          as(@critic) do
            @user_feedback = create(:user_feedback, user: @mod)
          end

          assert_no_difference(-> { UserFeedback.count }) do
            delete_auth user_feedback_path(@user_feedback), @mod
          end
        end
      end
    end
  end
end
