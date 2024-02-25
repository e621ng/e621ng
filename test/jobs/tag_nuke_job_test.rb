# frozen_string_literal: true

require "test_helper"

class TagNukeJobTest < ActiveJob::TestCase
  should "update posts" do
    p1 = create(:post, tag_string: "a aa b c")
    p2 = create(:post, tag_string: "a dd y z")
    TagNukeJob.perform_now("a", create(:user).id)
    p1.reload
    p2.reload
    assert_equal("aa b c", p1.tag_string)
    assert_equal("dd y z", p2.tag_string)
  end
end
