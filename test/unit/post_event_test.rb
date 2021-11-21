require 'test_helper'

class PostEventTest < ActiveSupport::TestCase
  def setup
    super

    Timecop.travel(2.weeks.ago) do
      CurrentUser.user = FactoryBot.create(:user)
      CurrentUser.ip_addr = "127.0.0.1"
    end

    @post = FactoryBot.create(:post)
    @post_flag = PostFlag.create(:post => @post, :reason => "aaa", :is_resolved => false)
  end

  def teardown
    super
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context "PostEvent.find_for_post" do
    should "work" do
      results = PostEvent.find_for_post(@post.id)
      assert_equal(2, results.size)
      assert_equal("flag", results[0].type_name)
    end
  end
end
