# frozen_string_literal: true

require "test_helper"

class TagAliasRequestTest < ActiveSupport::TestCase
  context "A tag alias request" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
    end

    should "handle invalid attributes" do
      tar = TagAliasRequest.new(:antecedent_name => "", :consequent_name => "", :reason => "reason")
      tar.create
      assert(tar.invalid?)
    end

    should "create a tag alias" do
      assert_difference("TagAlias.count", 1) do
        tar = TagAliasRequest.new(:antecedent_name => "aaa", :consequent_name => "bbb", :reason => "reason")
        tar.create
      end
      assert_equal("pending", TagAlias.last.status)
    end

    should "create a forum topic" do
      assert_difference("ForumTopic.count", 1) do
        tar = TagAliasRequest.new(:antecedent_name => "aaa", :consequent_name => "bbb", :reason => "reason")
        tar.create
      end
    end

    should "create a forum post" do
      assert_difference("ForumPost.count", 1) do
        tar = TagAliasRequest.new(:antecedent_name => "aaa", :consequent_name => "bbb", :reason => "reason")
        tar.create
      end
    end

    should "save the forum post id" do
      tar = TagAliasRequest.new(:antecedent_name => "aaa", :consequent_name => "bbb", :reason => "reason")
      tar.create
      assert_equal(tar.forum_topic.posts.first.id, tar.tag_relationship.forum_post.id)
    end

    should "fail validation if the reason is too short" do
      tar = TagAliasRequest.new(antecedent_name: "aaa", consequent_name: "bbb", reason: "")
      tar.create
      assert_match(/Reason is too short/, tar.errors.full_messages.join)
    end

    should "not create a forum post if skip_forum is true" do
      assert_no_difference("ForumPost.count") do
        tar = TagAliasRequest.new(antecedent_name: "aaa", consequent_name: "bbb", skip_forum: true)
        tar.create
      end
    end
  end
end
