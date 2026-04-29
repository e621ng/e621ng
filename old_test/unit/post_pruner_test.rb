# frozen_string_literal: true

require "test_helper"

class PostPrunerTest < ActiveSupport::TestCase
  setup do
    @user = create(:admin_user)
    CurrentUser.user = @user
    window = Danbooru.config.unapproved_post_deletion_window
    @old_post = create(:post, created_at: (window + 1.day).ago, is_pending: true)

    PostPruner.new.prune!
  end

  should "prune old pending posts" do
    @old_post.reload
    assert(@old_post.is_deleted?)
  end
end
