# frozen_string_literal: true

require "test_helper"

class TakedownsControllerTest < ActionDispatch::IntegrationTest
  should "render the index" do
    create_list(:takedown, 2)
    get takedowns_path

    assert_response :success
  end

  should "render the index for admins" do
    create_list(:takedown, 2)
    get_auth takedowns_path, create(:admin_user)

    assert_response :success
  end

  should "allow creation" do
    takedown_post = create(:post)
    post takedowns_path, params: { takedown: { email: "dummy@example.com", reason: "foo", post_ids: "#{takedown_post.id} #{takedown_post.id + 1}" }, format: :json }

    takedown = Takedown.last
    assert_redirected_to takedown_path(takedown, code: takedown.vericode)
    assert_equal(takedown_post.id.to_s, takedown.post_ids)
    assert_operator(takedown.vericode.length, :>, 8)
  end
end
