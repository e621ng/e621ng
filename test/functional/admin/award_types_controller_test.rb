# frozen_string_literal: true

require "test_helper"

module Admin
  class AwardTypesControllerTest < ActionDispatch::IntegrationTest
    context "The admin award types controller" do
      setup do
        @admin = create(:admin_user)
        @member = create(:user)
        CurrentUser.user = @admin
        @award_type = create(:award_type)
      end

      context "index action" do
        should "render for admin" do
          get_auth admin_award_types_path, @admin
          assert_response :success
        end

        should "deny non-admin" do
          get_auth admin_award_types_path, @member
          assert_response 403
        end
      end

      context "new action" do
        should "render for admin" do
          get_auth new_admin_award_type_path, @admin
          assert_response :success
        end
      end

      context "create action" do
        should "create an award type" do
          assert_difference("AwardType.count", 1) do
            post_auth admin_award_types_path, @admin, params: { award_type: { name: "Best Post", description: "Given for excellent posts" } }
          end
          assert_redirected_to admin_award_types_path
        end

        should "deny non-admin" do
          assert_no_difference("AwardType.count") do
            post_auth admin_award_types_path, @member, params: { award_type: { name: "Best Post" } }
          end
          assert_response 403
        end
      end

      context "edit action" do
        should "render for admin" do
          get_auth edit_admin_award_type_path(@award_type), @admin
          assert_response :success
        end
      end

      context "update action" do
        should "update an award type" do
          put_auth admin_award_type_path(@award_type), @admin, params: { award_type: { name: "Updated Name" } }
          assert_redirected_to admin_award_types_path
          assert_equal "Updated Name", @award_type.reload.name
        end
      end

      context "destroy action" do
        should "delete an award type" do
          assert_difference("AwardType.count", -1) do
            delete_auth admin_award_type_path(@award_type), @admin
          end
          assert_redirected_to admin_award_types_path
        end

        should "deny non-admin" do
          assert_no_difference("AwardType.count") do
            delete_auth admin_award_type_path(@award_type), @member
          end
          assert_response 403
        end
      end
    end
  end
end
