require 'test_helper'

class PostDisapprovalTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      @alice = FactoryBot.create(:moderator_user, name: "alice")
      CurrentUser.user = @alice
      CurrentUser.ip_addr = "127.0.0.1"
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "A post disapproval" do
      setup do
        @post_1 = FactoryBot.create(:post, :is_pending => true)
        @post_2 = FactoryBot.create(:post, :is_pending => true)
      end

      context "#search" do
        should "work" do
          disapproval1 = FactoryBot.create(:post_disapproval, user: @alice, post: @post_1, reason: "breaks_rules")
          disapproval2 = FactoryBot.create(:post_disapproval, user: @alice, post: @post_2, reason: "poor_quality", message: "bad anatomy")

          assert_equal([disapproval1.id], PostDisapproval.search(reason: "breaks_rules").pluck(:id))
          assert_equal([disapproval2.id], PostDisapproval.search(message: "bad anatomy").pluck(:id))
          assert_equal([disapproval2.id, disapproval1.id], PostDisapproval.search(creator_name: "alice").pluck(:id))
        end
      end
    end
  end
end
