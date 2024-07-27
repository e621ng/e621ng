# frozen_string_literal: true

require "test_helper"

class PostPrunerTest < ActiveSupport::TestCase
  setup do
    @user = create(:admin_user)
    CurrentUser.user = @user
    @old_post = create(:post, created_at: 31.days.ago, is_pending: true)

    PostPruner.new.prune!
  end

  should "prune old pending posts" do
    @old_post.reload
    assert(@old_post.is_deleted?)
  end
end
