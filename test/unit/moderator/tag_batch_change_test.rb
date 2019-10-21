require "test_helper"

module Moderator
  class TagBatchChangeTest < ActiveSupport::TestCase
    def setup
      super
    end

    context "a tag batch change" do
      setup do
        @user = FactoryBot.create(:moderator_user)
        CurrentUser.user = @user
        CurrentUser.ip_addr = "127.0.0.1"
        @post = FactoryBot.create(:post, :tag_string => "aaa")
      end

      teardown do
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      context "#estimate_update_count" do
        setup do
          @change = TagBatchChange.new("aaa", "bbb", @user.id, "127.0.0.1")
        end

        should "find the correct count" do
          assert_equal(1, @change.estimate_update_count)
        end
      end

      should "execute" do
        tag_batch_change = TagBatchChange.new("aaa", "bbb", @user.id, "127.0.0.1")
        tag_batch_change.perform
        @post.reload
        assert_equal("bbb", @post.tag_string)
      end

      should "move blacklists" do
        @user.update(blacklisted_tags: "123 456\n789\n")
        tag_batch_change = TagBatchChange.new("456", "xxx", @user.id, "127.0.0.1")
        tag_batch_change.perform
        @user.reload
        assert_equal("123 xxx\n789", @user.blacklisted_tags)
      end

      should "raise an error if there is no predicate" do
        tag_batch_change = TagBatchChange.new("", "bbb", @user.id, "127.0.0.1")
        assert_raises(TagBatchChange::Error) do
          tag_batch_change.perform
        end
      end
    end
  end
end
