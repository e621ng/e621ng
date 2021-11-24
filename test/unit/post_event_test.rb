require 'test_helper'

class PostEventTest < ActiveSupport::TestCase
  def setup
    super

    Timecop.travel(2.weeks.ago) do
      CurrentUser.user = FactoryBot.create(:user)
      CurrentUser.ip_addr = "127.0.0.1"
    end

    @post = FactoryBot.create(:post)
    create(:post_flag, post: @post, is_resolved: false)
    @post.approve!
  end

  def teardown
    super
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context "PostEvent.find_for_post" do
    should "work" do
      results = PostEvent.find_for_post(@post.id)
      assert_equal("approval", results[0].type_name)
      assert_equal("flag", results[1].type_name)
    end
  end
end
