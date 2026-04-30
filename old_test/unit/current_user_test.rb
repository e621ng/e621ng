# frozen_string_literal: true

require "test_helper"

class CurrentUserTest < ActiveSupport::TestCase
  context "A scoped current user" do
    should "reset the current user after the block has exited" do
      user1 = create(:user)
      user2 = create(:user)
      CurrentUser.user = user1
      as(user2, nil) do
        assert_equal(user2.id, CurrentUser.user.id)
      end
      assert_equal(user1.id, CurrentUser.user.id)
    end

    should "reset the current user even if an exception is thrown" do
      user1 = create(:user)
      user2 = create(:user)
      CurrentUser.user = user1
      assert_raises(RuntimeError) do
        as(user2, nil) do
          assert_equal(user2.id, CurrentUser.user.id)
          raise "ERROR"
        end
      end
      assert_equal(user1.id, CurrentUser.user.id)
    end
  end
end
