# frozen_string_literal: true

require "test_helper"

class TagBatchJobTest < ActiveJob::TestCase
  should "update posts" do
    p1 = create(:post, tag_string: "a aa b c")
    p2 = create(:post, tag_string: "a dd y z")
    TagBatchJob.perform_now("a", "d", create(:user).id)
    p1.reload
    p2.reload
    assert_equal("aa b c d", p1.tag_string)
    assert_equal("d dd y z", p2.tag_string)
  end

  should "migrate users blacklists" do
    initial_blacklist = <<~BLACKLIST.chomp
      tag
      a tag
      a tag b
      b tag
      -tag

      something-else
      tagging
    BLACKLIST
    expected_blacklist = <<~BLACKLIST.chomp
      new
      a new
      a new b
      b new
      -new

      something-else
      tagging
    BLACKLIST

    u = create(:user, blacklisted_tags: initial_blacklist)
    create(:user, blacklisted_tags: "aaa")
    TagBatchJob.perform_now("tag", "new", u.id)
    u.reload

    assert_equal(expected_blacklist, u.blacklisted_tags)
  end
end
