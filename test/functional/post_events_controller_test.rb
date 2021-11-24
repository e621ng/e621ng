require 'test_helper'

class PostEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to(2.weeks.ago) do
      @user = create(:user)
      @mod = create(:mod_user)
    end

    as_user do
      @post = create(:post)
      create(:post_flag, post: @post)
      @post.approve!(@mod)
    end
  end

  context "get /posts/:post_id/events" do
    should "render" do
      get_auth post_events_path(post_id: @post.id), @user
      assert_response :ok
    end

    should "render for mods" do
      get_auth post_events_path(post_id: @post.id), @mod
      assert_response :success
    end
  end
end
