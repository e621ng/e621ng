# frozen_string_literal: true

require "test_helper"

class TagAliasTest < ActiveSupport::TestCase
  context "A tag alias" do
    setup do
      @admin = create(:admin_user)

      user = create(:user, created_at: 1.month.ago)
      CurrentUser.user = user
    end

    context "on validation" do
      subject do
        create(:tag, name: "aaa")
        create(:tag, name: "bbb")
        create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      end

      should allow_value('active').for(:status)
      should allow_value('deleted').for(:status)
      should allow_value('pending').for(:status)
      should allow_value('processing').for(:status)
      should allow_value('queued').for(:status)
      should allow_value('error: derp').for(:status)

      should_not allow_value('ACTIVE').for(:status)
      should_not allow_value('error').for(:status)
      should_not allow_value('derp').for(:status)

      should allow_value(nil).for(:forum_topic_id)
      should_not allow_value(-1).for(:forum_topic_id).with_message("must exist", against: :forum_topic)

      should allow_value(nil).for(:approver_id)
      should_not allow_value(-1).for(:approver_id).with_message("must exist", against: :approver)

      should_not allow_value(nil).for(:creator_id)
      should_not allow_value(-1).for(:creator_id).with_message("must exist", against: :creator)

      should "not allow duplicate active aliases" do
        ta1 = create(:tag_alias)
        assert(ta1.valid?)

        assert_raises(ActiveRecord::RecordInvalid) do
          create(:tag_alias, status: "pending")
        end
      end
    end

    context "#estimate_update_count" do
      setup do
        reset_post_index
        create(:post, tag_string: "aaa bbb ccc")
        @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      end

      should "get the right count" do
        assert_equal(1, @alias.estimate_update_count)
      end
    end

    should "populate the creator information" do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      assert_equal(CurrentUser.user.id, ta.creator_id)
    end

    should "convert a tag to its normalized version" do
      tag1 = create(:tag, name: "aaa")
      tag2 = create(:tag, name: "bbb")
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")

      assert_equal(["bbb"], TagAlias.to_aliased("aaa"))
      assert_equal(["bbb", "ccc"], TagAlias.to_aliased(["aaa", "ccc"]))
      assert_equal(["ccc", "bbb"], TagAlias.to_aliased(["ccc", "bbb"]))
      assert_equal(["bbb"], TagAlias.to_aliased(["aaa", "aaa"]))
    end

    should "update any affected posts when saved" do
      post1 = create(:post, tag_string: "aaa bbb")
      post2 = create(:post, tag_string: "ccc ddd")

      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "ccc")
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal("bbb ccc", post1.reload.tag_string)
      assert_equal("ccc ddd", post2.reload.tag_string)
    end

    should "not validate for transitive relations" do
      ta1 = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc")
      assert_difference("TagAlias.count", 0) do
        ta2 = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
        ta2.save
        assert(ta2.errors.any?, "Tag alias should be invalid")
        assert_equal("A tag alias for bbb already exists", ta2.errors.full_messages.join)
      end
    end

    should "move existing aliases" do
      ta1 = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      ta2 = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc", status: "pending")
      with_inline_jobs do
        ta1.approve!(approver: @admin)
        ta2.approve!(approver: @admin)
      end

      assert_equal("ccc", ta1.reload.consequent_name)
    end

    should "move existing implications" do
      ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ta = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc")
      with_inline_jobs { ta.approve!(approver: @admin) }

      ti.reload
      assert_equal("ccc", ti.consequent_name)
    end

    should "not push the antecedent's category to the consequent if the antecedent is general" do
      tag1 = create(:tag, name: "aaa")
      tag2 = create(:tag, name: "bbb", category: 1)
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      tag2.reload
      assert_equal(1, tag2.category)
    end

    should "push the antecedent's category to the consequent if the consequent is non-general" do
      tag1 = create(:tag, name: "aaa", category: 1)
      tag2 = create(:tag, name: "bbb", category: 3)
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal(3, tag2.reload.category)
    end

    should "push the antecedent's category to the consequent" do
      tag1 = create(:tag, name: "aaa", category: 1)
      tag2 = create(:tag, name: "bbb", category: 0)
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal(1, tag2.reload.category)
    end

    should "not push the antecedent's category if the consequent is locked" do
      tag1 = create(:tag, name: "aaa", category: 1)
      tag2 = create(:tag, name: "bbb", category: 3, is_locked: true)
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal(3, tag2.reload.category)
    end

    should "not fail if an artist with the same name is locked" do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      artist = as(@admin) { create(:artist, name: "aaa", is_locked: true) }
      artist.tag.update(category: Tag.categories.artist)

      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal("active", ta.reload.status)
      assert_equal("bbb", artist.reload.name)
    end

    should "error on approve if its not valid anymore" do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
      ta.save(validate: false)
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_match "error", ta.reload.status
    end

    should "allow rejecting if an active duplicate exists" do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
      ta.save(validate: false)
      ta.reject!

      assert_equal "deleted", ta.reload.status
    end

    should "allow rejecting if an active transitive exists" do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "bbb", consequent_name: "aaa", status: "pending", creator: @admin)
      ta.save(validate: false)
      ta.reject!

      assert_equal "deleted", ta.reload.status
    end

    should "update locked tags on approve" do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      post1 = create(:post, locked_tags: "aaa foo")
      post2 = create(:post, locked_tags: "-aaa foo")
      with_inline_jobs { ta.approve!(approver: @admin) }

      assert_equal("bbb foo", post1.reload.locked_tags)
      assert_equal("-bbb foo", post2.reload.locked_tags)
    end

    context "with an associated forum topic" do
      setup do
        @admin = create(:admin_user)
        as(@admin) do
          @topic = create(:forum_topic, title: TagAliasRequest.topic_title("aaa", "bbb"))
          @post = create(:forum_post, topic_id: @topic.id, body: TagAliasRequest.command_string("aaa", "bbb"))
          @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", forum_topic: @topic, forum_post: @post, status: "pending")
        end
      end

      should "update the topic when processed" do
        assert_difference("ForumPost.count") do
          with_inline_jobs { @alias.approve!(approver: @admin) }
        end
      end

      should "update the parent post" do
        previous = @post.body
        with_inline_jobs { @alias.approve!(approver: @admin) }
        @post.reload
        assert_not_equal(previous, @post.body)
      end

      should "update the topic when rejected" do
        assert_difference("ForumPost.count") do
          @alias.reject!
        end
      end

      should "update the topic when failed" do
        TagAlias.any_instance.stubs(:update_blacklists).raises(Exception, "oh no")
        with_inline_jobs { @alias.approve!(approver: @admin) }
        @topic.reload
        @alias.reload

        assert_equal("[FAILED] Tag alias: aaa -> bbb", @topic.title)
        assert_match(/error: oh no/, @alias.status)
        assert_match(/The tag alias .* failed during processing/, @topic.posts.last.body)
      end
    end
  end
end
