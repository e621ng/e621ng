# frozen_string_literal: true

require "test_helper"

class AwardsControllerTest < ActionDispatch::IntegrationTest
  context "The awards controller" do
    setup do
      @admin = create(:admin_user)
      @janitor = create(:janitor_user)
      @member = create(:user)
      @recipient = create(:user)
      @award_type = as(@admin) { create(:award_type) }
      @award = as(@janitor) { create(:award, award_type: @award_type, user: @recipient, creator: @janitor) }
    end

    context "index action" do
      should "render for any user" do
        get awards_path
        assert_response :success
      end

      should "filter by user" do
        get awards_path(search: { user_name: @recipient.name })
        assert_response :success
      end
    end

    context "new action" do
      should "render for staff" do
        get_auth new_award_path, @janitor
        assert_response :success
      end

      should "deny members" do
        get_auth new_award_path, @member
        assert_response 403
      end
    end

    context "create action" do
      should "allow staff to give an award" do
        another_user = create(:user)
        assert_difference("Award.count", 1) do
          post_auth awards_path, @janitor, params: { award: { award_type_id: @award_type.id, user_id: another_user.id } }
        end
        assert_redirected_to user_path(another_user.id)
      end

      should "deny members" do
        assert_no_difference("Award.count") do
          post_auth awards_path, @member, params: { award: { award_type_id: @award_type.id, user_id: @recipient.id } }
        end
        assert_response 403
      end
    end

    context "destroy action" do
      should "allow the awarding staff member to revoke" do
        assert_difference("Award.count", -1) do
          delete_auth award_path(@award), @janitor
        end
      end

      should "allow an admin to revoke" do
        assert_difference("Award.count", -1) do
          delete_auth award_path(@award), @admin
        end
      end

      should "deny a different staff member" do
        other_janitor = create(:janitor_user)
        assert_no_difference("Award.count") do
          delete_auth award_path(@award), other_janitor
        end
        assert_response 403
      end

      should "deny a member" do
        assert_no_difference("Award.count") do
          delete_auth award_path(@award), @member
        end
        assert_response 403
      end
    end
  end
end
