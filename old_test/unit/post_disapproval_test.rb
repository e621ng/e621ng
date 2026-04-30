# frozen_string_literal: true

require "test_helper"

class PostDisapprovalTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      @alice = create(:moderator_user, name: "alice")
      CurrentUser.user = @alice
    end

    context "A post disapproval" do
      setup do
        @post_1 = create(:post, is_pending: true)
        @post_2 = create(:post, is_pending: true)
      end

      context "#search" do
        should "work" do
          disapproval1 = create(:post_disapproval, user: @alice, post: @post_1, reason: "borderline_quality")
          disapproval2 = create(:post_disapproval, user: @alice, post: @post_2, reason: "borderline_relevancy", message: "looks human")

          assert_equal([disapproval1.id], PostDisapproval.search(reason: "borderline_quality").pluck(:id))
          assert_equal([disapproval2.id], PostDisapproval.search(message: "looks human").pluck(:id))
          assert_equal([disapproval2.id, disapproval1.id], PostDisapproval.search(creator_name: "alice").pluck(:id))
        end
      end
    end
  end
end
