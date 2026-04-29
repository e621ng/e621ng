# frozen_string_literal: true

require "test_helper"

class AvoidPostingTest < ActiveSupport::TestCase
  context "An avoid posting entry" do
    setup do
      @bd_user = create(:bd_staff_user)
      CurrentUser.user = @bd_user
      @avoid_posting = create(:avoid_posting)
    end

    should "create an artist" do
      assert_difference("Artist.count", 1) do
        create(:avoid_posting)
      end
    end

    should "create a create modaction" do
      assert_difference("ModAction.count", 1) do
        create(:avoid_posting)
      end

      assert_equal("avoid_posting_create", ModAction.last.action)
    end

    should "create an update modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(details: "test")
      end

      assert_equal("avoid_posting_update", ModAction.last.action)
    end

    should "create a delete modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(is_active: false)
      end

      assert_equal("avoid_posting_delete", ModAction.last.action)
    end

    should "create an undelete modaction" do
      @avoid_posting.update_column(:is_active, false)

      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(is_active: true)
      end

      assert_equal("avoid_posting_undelete", ModAction.last.action)
    end

    should "create a destroy modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.destroy
      end

      assert_equal("avoid_posting_destroy", ModAction.last.action)
    end

    should "create a version when updated" do
      assert_difference("AvoidPostingVersion.count", 1) do
        @avoid_posting.update(details: "test")
      end

      assert_equal("test", AvoidPostingVersion.last.details)
    end
  end
end
