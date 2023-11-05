require 'test_helper'

class PostTest < ActiveSupport::TestCase
  def assert_tag_match(posts, query)
    assert_equal(posts.map(&:id), Post.tag_match(query).pluck(:id))
  end

  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    CurrentUser.user = @user
    reset_post_index
  end

  context "Deletion:" do
    context "Expunging a post" do
      # That belonged in a museum!
      setup do
        @upload = UploadService.new(attributes_for(:jpg_upload)).start!
        @post = @upload.post
        FavoriteManager.add!(user: @post.uploader, post: @post)
      end

      should "delete the files" do
        assert_nothing_raised { @post.file(:preview) }
        assert_nothing_raised { @post.file(:original) }

        @post.expunge!

        assert_raise(StandardError) { @post.file(:preview) }
        assert_raise(StandardError) { @post.file(:original) }
      end

      should "remove all favorites" do
        @post.expunge!

        assert_equal(0, Favorite.for_user(@post.uploader_id).where("post_id = ?", @post.id).count)
      end

      should "decrement the uploader's upload count" do
        assert_difference("@post.uploader.reload.post_upload_count", -1) do
          @post.expunge!
        end
      end

      should_eventually "decrement the user's note update count" do
        create(:note, post: @post)
        assert_difference(["@post.uploader.reload.note_update_count"], -1) do
          @post.expunge!
        end
      end

      should_eventually "decrement the user's post update count" do
        assert_difference(["@post.uploader.reload.post_update_count"], -1) do
          @post.expunge!
        end
      end

      should "decrement the user's favorite count" do
        assert_difference(["@post.uploader.reload.favorite_count"], -1) do
          @post.expunge!
        end
      end

      should "remove the post from iqdb" do
        @post.expects(:remove_iqdb_async).once
        @post.expunge!
      end

      context "that is status locked" do
        setup do
          @post.update(is_status_locked: true)
        end

        should "not destroy the record" do
          @post.expunge!
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      context "that belongs to a pool" do
        setup do
          @pool = create(:pool)
          @pool.add!(@post)

          @post.expunge!
          @pool.reload
        end

        should "remove the post from all pools" do
          assert_equal([], @pool.post_ids)
        end

        should "destroy the record" do
          assert_equal([], @post.errors.full_messages)
          assert_equal(0, Post.where("id = ?", @post.id).count)
        end
      end
    end

    context "Deleting a post" do
      context "that is status locked" do
        setup do
          @post = create(:post, is_status_locked: true)
        end

        should "fail" do
          @post.delete!("test")
          assert_equal(["Is status locked ; cannot delete post"], @post.errors.full_messages)
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      context "that is pending" do
        setup do
          @post = create(:post, is_pending: true)
        end

        should "succeed" do
          @post.delete!("test")

          assert_equal(true, @post.is_deleted)
          assert_equal(1, @post.flags.size)
          assert_match(/test/, @post.flags.last.reason)
        end
      end

      context "that is still in cooldown after being flagged" do
        should "succeed" do
          flag = create(:post_flag)
          assert_equal([], flag.errors.full_messages)
          flag.post.delete!("test deletion")

          assert_equal(true, flag.post.is_deleted)
          assert_equal(2, flag.post.flags.size)
        end
      end

      should "toggle the is_deleted flag" do
        post = create(:post)
        assert_equal(false, post.is_deleted?)
        post.delete!("test")
        assert_equal(true, post.is_deleted?)
      end
    end
  end

  context "Parent:" do
    setup do
      @parent = create(:post, tag_string: "a b c d", source: "a\nb\nc")
      @post = create(:post, parent_id: @parent.id, tag_string: "c d e f", source: "b\nc\nd")
    end
    should "Copy tags to parent" do
      @post.copy_tags_to_parent
      @post.parent.save
      assert_equal(@parent.reload.tag_string, "a b c d e f")
    end
    should "Copy sources to parent" do
      @post.copy_sources_to_parent
      @post.parent.save
      assert_equal(@parent.reload.source, "a\nb\nc\nd")
    end
  end

  context "Parenting:" do
    context "Assigning a parent to a post" do
      should "update the has_children flag on the parent" do
        p1 = create(:post)
        assert(!p1.has_children?, "Parent should not have any children")
        c1 = create(:post, parent_id: p1.id)
        p1.reload
        assert(p1.has_children?, "Parent not updated after child was added")
      end

      should "update the has_children flag on the old parent" do
        p1 = create(:post)
        p2 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.parent_id = p2.id
        c1.save
        p1.reload
        p2.reload
        assert(!p1.has_children?, "Old parent should not have a child")
        assert(p2.has_children?, "New parent should have a child")
      end
    end

    context "Expunging a post with" do
      context "a parent" do
        should "reset the has_children flag of the parent" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.expunge!
          p1.reload
          assert_equal(false, p1.has_children?)
        end

        should "update the parent's has_children flag" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.expunge!
          p1.reload
          assert(!p1.has_children?, "Parent should not have children")
        end
      end

      context "one child" do
        should "remove the parent of that child" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          p1.expunge!
          c1.reload
          assert_nil(c1.parent)
        end
      end

      context "two or more children" do
        setup do
          # ensure initial post versions won't be merged.
          travel_to(1.day.ago) do
            @p1 = create(:post)
            @c1 = create(:post, parent_id: @p1.id)
            @c2 = create(:post, parent_id: @p1.id)
            @c3 = create(:post, parent_id: @p1.id)
          end
        end

        should "reparent all children to the first child" do
          @p1.expunge!
          @c1.reload
          @c2.reload
          @c3.reload

          assert_nil(@c1.parent_id)
          assert_equal(@c1.id, @c2.parent_id)
          assert_equal(@c1.id, @c3.parent_id)
        end

        should "save a post version record for each child" do
          assert_difference(["@c1.versions.count", "@c2.versions.count", "@c3.versions.count"]) do
            @p1.expunge!
            @c1.reload
            @c2.reload
            @c3.reload
          end
        end

        should "set the has_children flag on the new parent" do
          @p1.expunge!
          assert_equal(true, @c1.reload.has_children?)
        end
      end
    end

    context "Deleting a post with" do
      context "a parent" do
        should "not reassign favorites to the parent by default" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          user = create(:privileged_user)
          FavoriteManager.add!(user: user, post: c1)
          c1.delete!("test")
          p1.reload
          assert(Favorite.exists?(:post_id => c1.id, :user_id => user.id))
          assert(!Favorite.exists?(:post_id => p1.id, :user_id => user.id))
        end

        should "reassign favorites to the parent if specified" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          user = create(:privileged_user)
          FavoriteManager.add!(user: user, post: c1)
          with_inline_jobs { c1.delete!("test", move_favorites: true) }
          p1.reload
          assert(!Favorite.exists?(:post_id => c1.id, :user_id => user.id), "Child should not still have favorites")
          assert(Favorite.exists?(:post_id => p1.id, :user_id => user.id), "Parent should have favorites")
        end

        should "not update the parent's has_children flag" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.delete!("test")
          p1.reload
          assert(p1.has_children?, "Parent should have children")
        end

        should "clear the has_active_children flag when the 'move favorites' option is set" do
          user = create(:privileged_user)
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          FavoriteManager.add!(user: user, post: c1)

          assert_equal(true, p1.reload.has_active_children?)
          c1.delete!("test", :move_favorites => true)
          assert_equal(false, p1.reload.has_active_children?)
        end
      end

      context "one child" do
        should "not remove the has_children flag" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          p1.delete!("test")
          p1.reload
          assert_equal(true, p1.has_children?)
        end

        should "not remove the parent of that child" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          p1.delete!("test")
          c1.reload
          assert_not_nil(c1.parent)
        end
      end

      context "two or more children" do
        should "not reparent all children to the first child" do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c2 = create(:post, parent_id: p1.id)
          c3 = create(:post, parent_id: p1.id)
          p1.delete!("test")
          c1.reload
          c2.reload
          c3.reload
          assert_equal(p1.id, c1.parent_id)
          assert_equal(p1.id, c2.parent_id)
          assert_equal(p1.id, c3.parent_id)
        end
      end
    end

    context "Undeleting a post with a parent" do
      should "update with a new approver" do
        new_user = create(:moderator_user)
        p1 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.delete!("test")
        as(new_user) do
          c1.undelete!
        end
        p1.reload
        assert_equal(new_user.id, c1.approver_id)
      end

      should "preserve the parent's has_children flag" do
        p1 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.delete!("test")
        c1.undelete!
        p1.reload
        assert_not_nil(c1.parent_id)
        assert(p1.has_children?, "Parent should have children")
      end
    end
  end

  context "Moderation:" do
    context "A deleted post" do
      setup do
        @post = create(:post, is_deleted: true)
      end

      context "that is status locked" do
        setup do
          @post.update(is_status_locked: true)
        end

        should "not allow undeletion" do
          @post.undelete!
          assert_equal(["Is status locked ; cannot undelete post"], @post.errors.full_messages)
          assert_equal(true, @post.is_deleted?)
        end
      end

      context "when undeleted" do
        should "be undeleted" do
          @post.undelete!
          assert_equal(false, @post.reload.is_deleted?)
        end
      end
    end

    context "An approved post" do
      should "be flagged" do
        post = create(:post)
        assert_difference(-> { PostFlag.count }, 1) do
          create(:post_flag, post: post)
        end
        assert(post.is_flagged?, "Post should be flagged.")
        assert_equal(1, post.flags.count)
      end

      should "not be flagged if no reason is given" do
        post = create(:post)
        assert_no_difference(-> { PostFlag.count }) do
          post.flags.create(reason_name: "")
        end
      end
    end

    context "An unapproved post" do
      should "preserve the approver's identity when approved" do
        post = create(:post, is_pending: true)
        post.approve!
        assert_equal(post.approver_id, CurrentUser.id)
      end

      context "that was previously approved by person X" do
        setup do
          @user = create(:moderator_user, name: "xxx")
          @user2 = create(:moderator_user, name: "yyy")
          @post = create(:post)
          @post.approve!(@user)
          @post.unapprove!
        end

        should "allow person Y to approve the post" do
          @post.approve!(@user2)
          assert(@post.valid?)
        end
      end

      context "that has been reapproved" do
        setup do
          @post = create(:post)
          create(:post_flag, post: @post)
          @post.reload
        end

        should "no longer be pending" do
          @post.approve!
          assert(@post.errors.empty?, @post.errors.full_messages.join(", "))
          @post.reload
          assert_equal(true, @post.is_flagged?)
          assert_equal(false, @post.is_pending?)
        end
      end
    end

    context "A status locked post" do
      setup do
        @post = create(:post, is_status_locked: true, is_pending: true)
      end

      should "not allow new flags" do
        flag = build(:post_flag, post: @post)
        flag.validate
        assert_equal(["Post is locked and cannot be flagged"], flag.errors.full_messages)
      end

      should "not allow approval" do
        assert_no_difference(-> { PostApproval.count }) do
          @post.approve!
        end
      end
    end
  end

  context "Tagging:" do
    context "A post" do
      setup do
        @post = create(:post)
      end

      context "as a new user" do
        setup do
          @post.update(:tag_string => "aaa bbb ccc ddd tagme")
          CurrentUser.user = create(:user)
        end

        # TODO: This was moved to be a controller concern to fix issues with internal post updates
        # should "not allow you to remove tags" do
        #   @post.update(:tag_string => "aaa")
        #   assert_equal(["You must have an account at least 1 week old to remove tags"], @post.errors.full_messages)
        # end

        should "allow you to remove request tags" do
          @post.update(:tag_string => "aaa bbb ccc ddd")
          @post.reload
          assert_equal("aaa bbb ccc ddd", @post.tag_string)
        end
      end

      context "with an artist tag that is then changed to copyright" do
        setup do
          CurrentUser.user = create(:janitor_user)
          with_inline_jobs do
            @post.update(tag_string: "art:abc")
            @post.update(tag_string: "copy:abc")
          end
          @post.reload
        end

        should "update the category of the tag" do
          assert_equal(Tag.categories.copyright, Tag.find_by_name("abc").category)
        end

        should "1234 update the category cache of the tag" do
          assert_equal(Tag.categories.copyright, Cache.fetch("tc:abc"))
        end

        should "update the tag counts of the posts" do
          assert_equal(0, @post.tag_count_artist)
          assert_equal(1, @post.tag_count_copyright)
          assert_equal(0, @post.tag_count_general)
        end
      end

      context "using a tag prefix on an aliased tag" do
        setup do
          create(:tag_alias, antecedent_name: "abc", consequent_name: "xyz")
          @post = Post.find(@post.id)
          @post.update(:tag_string => "art:abc")
          @post.reload
        end

        should "convert the tag to its normalized version" do
          assert_equal("xyz", @post.tag_string)
        end
      end

      context "with locked tags" do
        context "without aliases or implications" do
          setup do
            @post = create(:post, locked_tags: "abc -what bcd -def", tag_string: "test_tag def")
          end

          should "contain correct tags" do
            assert_equal("abc bcd test_tag", @post.tag_string)
          end
        end

        context "with aliases" do
          setup do
            create(:tag_alias, antecedent_name: "abc", consequent_name: "xyz")
            create(:tag_alias, antecedent_name: "def", consequent_name: "what")
            @post = create(:post, locked_tags: "abc bcd -def", tag_string: "test_tag def what")
          end

          should "contain correct tags" do
            assert_equal("bcd test_tag xyz", @post.tag_string)
          end
        end

        context "with implications" do
          should "contain correct tags" do
            create(:tag_implication, antecedent_name: "specific_tag", consequent_name: "base_tag")
            create(:tag_implication, antecedent_name: "female/female", consequent_name: "female")
            create(:tag_implication, antecedent_name: "male/male", consequent_name: "male")
            create(:tag_implication, antecedent_name: "trio", consequent_name: "group")
            locked_tags = "-base_tag -female/female male/male test_tag"
            tag_string = "specific_tag female/female group def"
            @post = create(:post, locked_tags: locked_tags, tag_string: tag_string)
            assert_equal("def group male male/male test_tag", @post.tag_string)
          end

          should "update the cache when implications change" do
            @post = create(:post, locked_tags: "-group", tag_string: "trio specific_tag")
            assert_equal("specific_tag trio", @post.tag_string)

            ti = create(:tag_implication, antecedent_name: "trio", consequent_name: "group", status: "pending")
            ti.approve!
            create(:tag_implication, antecedent_name: "specific_tag", consequent_name: "base_tag", status: "pending")
            @post.tag_string += " "
            @post.save
            assert_equal("specific_tag", @post.tag_string)

            ti.reject!
            @post.tag_string += " trio"
            @post.save
            assert_equal("specific_tag trio", @post.tag_string)
          end
        end

        context "with dnp tags" do
          should "prevent manually adding them" do
            @post = create(:post, locked_tags: "", tag_string: "a b c")
            @post.tag_string += " conditional_dnp"
            @post.save

            assert_equal("a b c", @post.tag_string)
            assert_nil(@post.locked_tags)
          end

          should "add dnp tags through an implication" do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, locked_tags: "", tag_string: "a b c")

            @post.tag_string += " artist"
            @post.save

            assert_equal("a artist avoid_posting b c", @post.tag_string)
            assert_equal("avoid_posting", @post.locked_tags)
          end

          should "prevent removing them" do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, tag_string: "a artist avoid_posting b c")

            @post.tag_string = "a b c"
            @post.warnings.clear
            @post.save
            assert_match(/Forcefully added 1 locked tag: avoid_posting/, @post.warnings.full_messages.join(" "))

            assert_equal("a avoid_posting b c", @post.tag_string)
          end

          should "not warn about dnp tags when dnp tags didn't change" do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, tag_string: "a artist avoid_posting b c")

            @post.tag_string += "d e f"
            @post.warnings.clear
            @post.save
            assert_no_match(/Forcefully added 1 locked tag: avoid_posting/, @post.warnings.full_messages.join(" "))
          end
        end
      end

      # TODO: Invalid tags are now reported as warnings, and don't trigger these.
      # context "tagged with a valid tag" do
      #   subject { @post }
      #
      #   should allow_value("touhou 100%").for(:tag_string)
      #   should allow_value("touhou FOO").for(:tag_string)
      #   should allow_value("touhou -foo").for(:tag_string)
      #   should allow_value("touhou pool:foo").for(:tag_string)
      #   should allow_value("touhou -pool:foo").for(:tag_string)
      #   should allow_value("touhou newpool:foo").for(:tag_string)
      #   should allow_value("touhou fav:self").for(:tag_string)
      #   should allow_value("touhou -fav:self").for(:tag_string)
      #   should allow_value("touhou upvote:self").for(:tag_string)
      #   should allow_value("touhou downvote:self").for(:tag_string)
      #   should allow_value("touhou parent:1").for(:tag_string)
      #   should allow_value("touhou child:1").for(:tag_string)
      #   should allow_value("touhou source:foo").for(:tag_string)
      #   should allow_value("touhou rating:z").for(:tag_string)
      #   should allow_value("touhou locked:rating").for(:tag_string)
      #   should allow_value("touhou -locked:rating").for(:tag_string)
      #
      #   # \u3000 = ideographic space, \u00A0 = no-break space
      #   should allow_value("touhou\u3000foo").for(:tag_string)
      #   should allow_value("touhou\u00A0foo").for(:tag_string)
      # end

      # TODO: These are now warnings and don't trigger these.
      # context "tagged with an invalid tag" do
      #   subject { @post }
      #
      #   context "that doesn't already exist" do
      #     should_not allow_value("touhou user:evazion").for(:tag_string)
      #     should_not allow_value("touhou *~foo").for(:tag_string)
      #     should_not allow_value("touhou *-foo").for(:tag_string)
      #     should_not allow_value("touhou ,-foo").for(:tag_string)
      #
      #     should_not allow_value("touhou ___").for(:tag_string)
      #     should_not allow_value("touhou ~foo").for(:tag_string)
      #     should_not allow_value("touhou _foo").for(:tag_string)
      #     should_not allow_value("touhou foo_").for(:tag_string)
      #     should_not allow_value("touhou foo__bar").for(:tag_string)
      #     should_not allow_value("touhou foo*bar").for(:tag_string)
      #     should_not allow_value("touhou foo,bar").for(:tag_string)
      #     should_not allow_value("touhou foo\abar").for(:tag_string)
      #     should_not allow_value("touhou café").for(:tag_string)
      #     should_not allow_value("touhou 東方").for(:tag_string)
      #   end
      #
      #   context "that already exists" do
      #     setup do
      #       %W(___ ~foo _foo foo_ foo__bar foo*bar foo,bar foo\abar café 東方).each do |tag|
      #         build(:tag, name: tag).save(validate: false)
      #       end
      #     end
      #
      #     should allow_value("touhou ___").for(:tag_string)
      #     should allow_value("touhou ~foo").for(:tag_string)
      #     should allow_value("touhou _foo").for(:tag_string)
      #     should allow_value("touhou foo_").for(:tag_string)
      #     should allow_value("touhou foo__bar").for(:tag_string)
      #     should allow_value("touhou foo*bar").for(:tag_string)
      #     should allow_value("touhou foo,bar").for(:tag_string)
      #     should allow_value("touhou foo\abar").for(:tag_string)
      #     should allow_value("touhou café").for(:tag_string)
      #     should allow_value("touhou 東方").for(:tag_string)
      #   end
      # end

      context "tagged with a metatag" do

        context "for typing a tag" do
          setup do
            @post = create(:post, tag_string: "char:hoge")
            @tags = @post.tag_array
          end

          should "change the type" do
            assert(Tag.where(name: "hoge", category: 4).exists?, "expected 'moge' tag to be created as a character")
          end
        end

        context "for a parent" do
          setup do
            @parent = create(:post)
          end

          should "update the parent relationships for both posts" do
            @post.update(:tag_string => "aaa parent:#{@parent.id}")
            @post.reload
            @parent.reload
            assert_equal(@parent.id, @post.parent_id)
            assert(@parent.has_children?)
          end

          should "not allow self-parenting" do
            @post.update(:tag_string => "parent:#{@post.id}")
            assert_nil(@post.parent_id)
          end

          should "clear the parent with parent:none" do
            @post.update(:parent_id => @parent.id)
            assert_equal(@parent.id, @post.parent_id)

            @post.update(:tag_string => "parent:none")
            assert_nil(@post.parent_id)
          end

          should "clear the parent with -parent:1234" do
            @post.update(:parent_id => @parent.id)
            assert_equal(@parent.id, @post.parent_id)

            @post.update(:tag_string => "-parent:#{@parent.id}")
            assert_nil(@post.parent_id)
          end
        end

        context "for a pool" do
          context "on creation" do
            setup do
              @pool = create(:pool)
              @post = create(:post, tag_string: "aaa pool:#{@pool.id}")
            end

            should "add the post to the pool" do
              @post.reload
              @pool.reload
              assert_equal([@post.id], @pool.post_ids)
              assert_equal("pool:#{@pool.id}", @post.pool_string)
            end
          end

          context "negated" do
            setup do
              @pool = create(:pool)
              @post = create(:post, tag_string: "aaa")
              @pool.add(@post)
              @post.tag_string = "aaa -pool:#{@pool.id}"
              @post.save
            end

            should "remove the post from the pool" do
              @post.reload
              @pool.reload
              assert_equal([], @pool.post_ids)
              assert_equal("", @post.pool_string)
            end
          end

          context "id" do
            setup do
              @pool = create(:pool)
              @post.update(:tag_string => "aaa pool:#{@pool.id}")
            end

            should "add the post to the pool" do
              @post.reload
              @pool.reload
              assert_equal([@post.id], @pool.post_ids)
              assert_equal("pool:#{@pool.id}", @post.pool_string)
            end
          end

          context "name" do
            context "that exists" do
              setup do
                @pool = create(:pool, name: "abc")
                @post.update(:tag_string => "aaa pool:abc")
              end

              should "add the post to the pool" do
                @post.reload
                @pool.reload
                assert_equal([@post.id], @pool.post_ids)
                assert_equal("pool:#{@pool.id}", @post.pool_string)
              end
            end

            context "that doesn't exist" do
              should "create a new pool and add the post to that pool" do
                @post.update(:tag_string => "aaa newpool:abc")
                @pool = Pool.find_by_name("abc")
                @post.reload
                assert_not_nil(@pool)
                assert_equal([@post.id], @pool.post_ids)
                assert_equal("pool:#{@pool.id}", @post.pool_string)
              end
            end

            context "with special characters" do
              should "not strip '%' from the name" do
                @post.update(tag_string: "aaa newpool:ichigo_100%")
                assert(Pool.exists?(name: "ichigo_100%"))
              end
            end
          end
        end

        context "for a rating" do
          context "that is valid" do
            should "update the rating if the post is unlocked" do
              @post.update(:tag_string => "aaa rating:e")
              @post.reload
              assert_equal("e", @post.rating)
            end
          end

          context "that is invalid" do
            should "not update the rating" do
              @post.update(:tag_string => "aaa rating:z")
              @post.reload
              assert_equal("q", @post.rating)
            end
          end

          context "that is locked" do
            should "change the rating if locked in the same update" do
              @post.update(tag_string: "rating:e", is_rating_locked: true)

              assert(@post.valid?)
              assert_equal("e", @post.reload.rating)
            end

            should "not change the rating if locked previously" do
              @post.is_rating_locked = true
              @post.save

              @post.update(:tag_string => "rating:e")

              assert(@post.invalid?)
              assert_not_equal("e", @post.reload.rating)
            end
          end
        end

        context "for a fav" do
          should "add/remove the current user to the post's favorite listing" do
            @post.update(:tag_string => "aaa")
            FavoriteManager.add!(user: CurrentUser.user, post: @post)
            assert_equal("fav:#{@user.id}", @post.fav_string)

            FavoriteManager.remove!(user: CurrentUser.user, post: @post)
            assert_equal("", @post.fav_string)
          end
        end

        context "for a child" do
          should "add and remove children" do
            @children = create_list(:post, 3, parent_id: nil)

            @post.update(tag_string: "aaa child:#{@children.first.id}..#{@children.last.id}")
            assert_equal(true, @post.reload.has_children?)
            assert_equal(@post.id, @children[0].reload.parent_id)
            assert_equal(@post.id, @children[1].reload.parent_id)
            assert_equal(@post.id, @children[2].reload.parent_id)

            @post.update(tag_string: "aaa -child:#{@children.first.id}")
            assert_equal(true, @post.reload.has_children?)
            assert_nil(@children[0].reload.parent_id)
            assert_equal(@post.id, @children[1].reload.parent_id)
            assert_equal(@post.id, @children[2].reload.parent_id)

            @post.update(tag_string: "aaa child:none")
            assert_equal(false, @post.reload.has_children?)
            assert_nil(@children[0].reload.parent_id)
            assert_nil(@children[1].reload.parent_id)
            assert_nil(@children[2].reload.parent_id)
          end
        end

        context "for a source" do
          should "set the source with source:foo_bar_baz" do
            @post.update(:tag_string => "source:foo_bar_baz")
            assert_equal("foo_bar_baz", @post.source)
          end

          should 'set the source with source:"foo bar baz"' do
            @post.update(:tag_string => 'source:"foo bar baz"')
            assert_equal("foo bar baz", @post.source)
          end

          should 'strip the source with source:"  foo bar baz  "' do
            @post.update(:tag_string => 'source:"  foo bar baz  "')
            assert_equal("foo bar baz", @post.source)
          end

          should "clear the source with source:none" do
            @post.update(:source => "foobar")
            @post.update(:tag_string => "source:none")
            assert_equal("", @post.source)
          end
          should "add a source with +source:foo_bar" do
            @post.update(:source => "foobar")
            @post.update(:tag_string => "+source:foo_bar")
            assert_equal("foobar\nfoo_bar", @post.source)
          end
        end

        context "of" do
          setup do
            @janitor = create(:janitor_user)
          end

          context "locked:notes" do
            context "by a member" do
              should "not lock the notes" do
                @post.update(:tag_string => "locked:notes")
                assert_equal(false, @post.is_note_locked)
              end
            end

            context "by a janitor" do
              should "lock/unlock the notes" do
                as(@janitor) do
                  @post.update(:tag_string => "locked:notes")
                  assert_equal(true, @post.is_note_locked)

                  @post.update(:tag_string => "-locked:notes")
                  assert_equal(false, @post.is_note_locked)
                end
              end
            end
          end

          context "locked:rating" do
            context "by a member" do
              should "not lock the rating" do
                @post.update(:tag_string => "locked:rating")
                assert_equal(false, @post.is_rating_locked)
              end
            end

            context "by a janitor" do
              should "lock/unlock the rating" do
                as(@janitor) do
                  @post.update(:tag_string => "locked:rating")
                  assert_equal(true, @post.is_rating_locked)

                  @post.update(:tag_string => "-locked:rating")
                  assert_equal(false, @post.is_rating_locked)
                end
              end
            end
          end

          context "locked:status" do
            context "by a member" do
              should "not lock the status" do
                @post.update(:tag_string => "locked:status")
                assert_equal(false, @post.is_status_locked)
              end
            end

            context "by an admin" do
              should "lock/unlock the status" do
                as(create(:admin_user)) do
                  @post.update(:tag_string => "locked:status")
                  assert_equal(true, @post.is_status_locked)

                  @post.update(:tag_string => "-locked:status")
                  assert_equal(false, @post.is_status_locked)
                end
              end
            end
          end
        end
      end

      context "tagged with a negated tag" do
        should "remove the tag if present" do
          @post.update(:tag_string => "aaa bbb ccc")
          @post.update(:tag_string => "aaa bbb ccc -bbb")
          @post.reload
          assert_equal("aaa ccc", @post.tag_string)
        end

        should "resolve aliases" do
          create(:tag_alias, antecedent_name: "tr", consequent_name: "translation_request")
          @post.update(:tag_string => "aaa translation_request -tr")

          assert_equal("aaa", @post.tag_string)
        end
      end

      context "tagged with animated_gif or animated_png" do
        should "remove the tag if not a gif or png" do
          @post.update(tag_string: "tagme animated_gif")
          assert_equal("tagme", @post.tag_string)

          @post.update(tag_string: "tagme animated_png")
          assert_equal("tagme", @post.tag_string)
        end
      end

      should "have an array representation of its tags" do
        post = create(:post)
        post.reload
        post.set_tag_string("aaa bbb")
        assert_equal(%w(aaa bbb), post.tag_array)
        assert_equal(%w(tag1 tag2), post.tag_array_was)
      end

      context "with large dimensions" do
        setup do
          @post.image_width = 10_000
          @post.image_height = 10
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate dimension tags added automatically" do
          assert_match(/absurd_res/, @post.tag_string)
          assert_match(/hi_res/, @post.tag_string)
        end
      end

      context "with a large file size" do
        setup do
          @post.file_size = 31.megabytes
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file size tags added automatically" do
          assert_match(/huge_filesize/, @post.tag_string)
        end
      end

      context "with a .webm file extension" do
        setup do
          create(:tag_implication, antecedent_name: "webm", consequent_name: "animated")
          @post.file_ext = "webm"
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file type tag added automatically" do
          assert_match(/webm/, @post.tag_string)
        end

        should "apply implications after adding the file type tag" do
          assert(@post.has_tag?("animated"), "expected 'webm' to imply 'animated'")
        end
      end

      context "with a .swf file extension" do
        setup do
          @post.file_ext = "swf"
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file type tag added automatically" do
          assert_match(/flash/, @post.tag_string)
        end
      end

      context "that has been updated" do
        should "create a new version if it's the first version" do
          assert_difference("PostVersion.count", 1) do
            post = create(:post)
          end
        end

        should "create a new version if the post is updated" do
          post = create(:post)
          assert_difference("PostVersion.count", 1) do
            post.update(:tag_string => "zzz")
          end
        end

        should "increment the updater's post_update_count" do
          post = create(:post, tag_string: "aaa bbb ccc")

          assert_difference("CurrentUser.user.reload.post_update_count", 1) do
            post.update(:tag_string => "zzz")
          end
        end

        should "reset its tag array cache" do
          post = create(:post, tag_string: "aaa bbb ccc")
          user = create(:user)
          assert_equal(%w(aaa bbb ccc), post.tag_array)
          post.tag_string = "ddd eee fff"
          post.tag_string = "ddd eee fff"
          post.save
          assert_equal("ddd eee fff", post.tag_string)
          assert_equal(%w(ddd eee fff), post.tag_array)
        end

        should "create the actual tag records" do
          assert_difference("Tag.count", 3) do
            post = create(:post, tag_string: "aaa bbb ccc")
          end
        end

        should "update the post counts of relevant tag records" do
          post1 = create(:post, tag_string: "aaa bbb ccc")
          post2 = create(:post, tag_string: "bbb ccc ddd")
          post3 = create(:post, tag_string: "ccc ddd eee")
          assert_equal(1, Tag.find_by_name("aaa").post_count)
          assert_equal(2, Tag.find_by_name("bbb").post_count)
          assert_equal(3, Tag.find_by_name("ccc").post_count)
          post3.reload
          post3.tag_string = "xxx"
          post3.save
          assert_equal(1, Tag.find_by_name("aaa").post_count)
          assert_equal(2, Tag.find_by_name("bbb").post_count)
          assert_equal(2, Tag.find_by_name("ccc").post_count)
          assert_equal(1, Tag.find_by_name("ddd").post_count)
          assert_equal(0, Tag.find_by_name("eee").post_count)
          assert_equal(1, Tag.find_by_name("xxx").post_count)
        end

        should "update its tag counts" do
          artist_tag = create(:artist_tag)
          copyright_tag = create(:copyright_tag)
          general_tag = create(:tag)
          new_post = create(:post, tag_string: "#{artist_tag.name} #{copyright_tag.name} #{general_tag.name}")
          assert_equal(1, new_post.tag_count_artist)
          assert_equal(1, new_post.tag_count_copyright)
          assert_equal(1, new_post.tag_count_general)
          assert_equal(0, new_post.tag_count_character)
          assert_equal(3, new_post.tag_count)

          new_post.tag_string = "babs"
          new_post.save
          assert_equal(0, new_post.tag_count_artist)
          assert_equal(0, new_post.tag_count_copyright)
          assert_equal(1, new_post.tag_count_general)
          assert_equal(0, new_post.tag_count_character)
          assert_equal(1, new_post.tag_count)
        end

        should "merge any tag changes that were made after loading the initial set of tags part 1" do
          post = create(:post, tag_string: "aaa bbb ccc")

          # user a adds <ddd>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_a.save

          # user b removes <ccc> adds <eee>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb eee"
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)
          assert_equal(%w(aaa bbb ddd eee), TagQuery.scan(final_post.tag_string).sort)
        end

        should "merge any tag changes that were made after loading the initial set of tags part 2" do
          # This is the same as part 1, only the order of operations is reversed.
          # The results should be the same.

          post = create(:post, tag_string: "aaa bbb ccc")

          # user a removes <ccc> adds <eee>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb eee"
          post_edited_by_user_a.save

          # user b adds <ddd>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)
          assert_equal(%w(aaa bbb ddd eee), TagQuery.scan(final_post.tag_string).sort)
        end

        should "merge any parent, source, and rating changes that were made after loading the initial set" do
          post = create(:post, parent: nil, source: "", rating: "q")
          parent_post = create(:post)

          # user a changes rating to safe, adds parent
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_parent_id = ""
          post_edited_by_user_a.old_source = ""
          post_edited_by_user_a.old_rating = "q"
          post_edited_by_user_a.parent_id = parent_post.id
          post_edited_by_user_a.source = nil
          post_edited_by_user_a.rating = "s"
          post_edited_by_user_a.save

          # user b adds source
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_parent_id = ""
          post_edited_by_user_b.old_source = ""
          post_edited_by_user_b.old_rating = "q"
          post_edited_by_user_b.parent_id = nil
          post_edited_by_user_b.source = "http://example.com"
          post_edited_by_user_b.rating = "q"
          post_edited_by_user_b.save

          # final post should be rated safe and have the set parent and source
          final_post = Post.find(post.id)
          assert_equal(parent_post.id, final_post.parent_id)
          assert_equal("https://example.com", final_post.source)
          assert_equal("s", final_post.rating)
        end
      end

      context "that has been tagged with a metatag" do
        should "not include the metatag in its tag string" do
          post = create(:post)
          post.tag_string = "aaa pool:1234 pool:test rating:s fav:bob"
          post.save
          assert_equal("aaa", post.tag_string)
        end
      end

      context "when validating tags" do
        should "warn when creating a new general tag" do
          @post.add_tag("tag")
          @post.save

          assert_match(/Created 1 new tag: \[\[tag\]\]/, @post.warnings.full_messages.join)
        end

        should "warn when adding an artist tag without an artist entry" do
          @post.add_tag("artist:bkub")
          @post.save

          assert_match(/Artist \[\[bkub\]\] requires an artist entry./, @post.warnings.full_messages.join)
        end

        should "warn when a post from a known source is missing an artist tag" do
          post = build(:post, source: "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=65985331")
          post.save
          assert_match(/Artist tag is required/, post.warnings.full_messages.join)
        end

        should "warn when an upload doesn't have enough tags" do
          post = create(:post, tag_string: "tagme")
          assert_match(/Uploads must have at least \d+ general tags/, post.warnings.full_messages.join)
        end
      end
    end
  end

  context "Updating:" do
    context "an existing post" do
      setup { @post = create(:post) }

      should "call Tag.increment_post_counts with the correct params" do
        @post.reload
        Tag.expects(:increment_post_counts).once.with(["abc"])
        @post.update(tag_string: "tag1 abc")
      end
    end

    context "A rating unlocked post" do
      setup { @post = create(:post) }
      subject { @post }

      should "not allow values S, safe, derp" do
        ["S", "safe", "derp"].each do |rating|
          subject.rating = rating
          assert(!subject.valid?)
        end
      end

      should "allow values s, q, e" do
        ["s", "q", "e"].each do |rating|
          subject.rating = rating
          assert(subject.valid?)
        end
      end
    end

    context "A rating locked post" do
      setup { @post = create(:post, is_rating_locked: true) }
      subject { @post }

      should "not allow values S, safe, derp" do
        ["S", "safe", "derp"].each do |rating|
          subject.rating = rating
          assert(!subject.valid?)
        end
      end

      should "not allow values s, e" do
        ["s", "e"].each do |rating|
          subject.rating = rating
          assert(!subject.valid?)
        end
      end
    end
  end

  context "Favorites:" do
    context "Removing a post from a user's favorites" do
      setup do
        @user = create(:privileged_user)
        @post = create(:post)
        FavoriteManager.add!(user: @user, post: @post)
        @user.reload
      end

      should "decrement the user's favorite_count" do
        assert_difference("@user.reload.favorite_count", -1) do
          FavoriteManager.remove!(user: @user, post: @post)
        end
      end

      should "not decrement the post's score" do
        @member = create(:user)

        assert_no_difference("@post.score") { FavoriteManager.add!(user: @member, post: @post) }
        assert_no_difference("@post.score") { FavoriteManager.remove!(user: @member, post: @post) }
      end

      should "not decrement the user's favorite_count if the user did not favorite the post" do
        @post2 = create(:post)
        assert_no_difference("@user.reload.favorite_count") do
          FavoriteManager.remove!(user: @user, post: @post2)
        end
      end
    end

    context "Adding a post to a user's favorites" do
      setup do
        @user = create(:privileged_user)
        @post = create(:post)
      end

      should "periodically clean the fav_string" do
        @post.update_column(:fav_string, "fav:1 fav:1 fav:1")
        @post.update_column(:fav_count, 3)
        @post.append_user_to_fav_string(2)
        assert_equal("fav:1 fav:2", @post.fav_string)
        assert_equal(2, @post.fav_count)
      end

      # TODO: Needs to reload relationship to obtain non cached value
      should "increment the user's favorite_count" do
        assert_difference("@user.reload.favorite_count", 1) do
          FavoriteManager.add!(user: @user, post: @post)
        end
      end

      should "not increment the post's score" do
        @member = create(:user)
        FavoriteManager.add!(user: @user, post: @post)
        assert_equal(0, @post.score)
      end

      should "update the fav strings on the post" do
        FavoriteManager.add!(user: @user, post: @post)
        @post.reload
        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        assert_raises(Favorite::Error) { FavoriteManager.add!(user: @user, post: @post) }
        @post.reload
        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        FavoriteManager.remove!(user: @user, post: @post)
        @post.reload
        assert_equal("", @post.fav_string)
        assert(!Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        FavoriteManager.remove!(user: @user, post: @post)
        @post.reload
        assert_equal("", @post.fav_string)
        assert(!Favorite.exists?(:user_id => @user.id, :post_id => @post.id))
      end
    end

    context "Moving favorites to a parent post" do
      setup do
        @parent = create(:post)
        @child = create(:post, parent: @parent)

        @user1 = create(:user, enable_privacy_mode: true)
        @privileged1 = create(:privileged_user)
        @supervoter1 = create(:user)

        FavoriteManager.add!(user: @user1, post: @child)
        FavoriteManager.add!(user: @privileged1, post: @child)
        FavoriteManager.add!(user: @supervoter1, post: @child)
        FavoriteManager.add!(user: @supervoter1, post: @parent)

        with_inline_jobs { @child.give_favorites_to_parent }
        @child.reload
        @parent.reload
      end

      should "move the favorites" do
        assert_equal(0, @child.fav_count)
        assert_equal(0, @child.favorites.count)
        assert_equal("", @child.fav_string)
        assert_equal([], @child.favorites.pluck(:user_id))

        assert_equal(3, @parent.fav_count)
        assert_equal(3, @parent.favorites.count)
      end
    end
  end

  context "Pools:" do
    context "Removing a post from a pool" do
      should "update the post's pool string" do
        post = create(:post)
        pool = create(:pool)
        pool.add!(post)
        pool.remove!(post)
        post.reload
        assert_equal("", post.pool_string)
        pool.remove!(post)
        post.reload
        assert_equal("", post.pool_string)
      end
    end

    context "Adding a post to a pool" do
      should "update the post's pool string" do
        post = create(:post)
        pool = create(:pool)
        pool.add!(post)
        post.reload
        assert_equal("pool:#{pool.id}", post.pool_string)
        pool.add!(post)
        post.reload
        assert_equal("pool:#{pool.id}", post.pool_string)
        pool.remove!(post)
        post.reload
        assert_equal("", post.pool_string)
      end
    end
  end

  context "Uploading:" do
    context "Uploading a post" do
      should "capture who uploaded the post" do
        post = create(:post)
        user1 = create(:user)
        user2 = create(:user)
        user3 = create(:user)

        post.uploader = user1
        assert_equal(user1.id, post.uploader_id)

        post.uploader_id = user2.id
        assert_equal(user2.id, post.uploader_id)
        assert_equal(user2.id, post.uploader_id)
        assert_equal(user2.name, post.uploader_name)
      end

      context "tag post counts" do
        setup { @post = build(:post) }

        should "call Tag.increment_post_counts with the correct params" do
          Tag.expects(:increment_post_counts).once.with(["tag1", "tag2"])
          @post.save
        end
      end

      should "increment the uploaders post_upload_count" do
        assert_difference(-> { CurrentUser.user.post_upload_count }) do
          post = create(:post, uploader: CurrentUser.user)
          CurrentUser.user.reload
        end
      end
    end
  end

  context "Searching:" do
    should "return posts for the age:<1minute tag" do
      post = create(:post)
      assert_tag_match([post], "age:<1minute")
    end

    should "return posts for the age:<1minute tag when the user is in Pacific time zone" do
      post = create(:post)
      Time.zone = "Pacific Time (US & Canada)"
      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should "return posts for the age:<1minute tag when the user is in Tokyo time zone" do
      post = create(:post)
      Time.zone = "Asia/Tokyo"
      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should "return posts for the ' tag" do
      post1 = create(:post, tag_string: "'")
      post2 = create(:post, tag_string: "aaa bbb")

      assert_tag_match([post1], "'")
    end

    should "return posts for the ? tag" do
      post1 = create(:post, tag_string: "?")
      post2 = create(:post, tag_string: "aaa bbb")

      assert_tag_match([post1], "?")
    end

    should "return posts for 1 tag" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaa bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2, post1], "aaa")
    end

    should "return posts for a 2 tag join" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaa bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2], "aaa bbb")
    end

    should "return posts for a 2 tag union" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaab bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post3, post1], "~aaa ~ccc")
    end

    should "return posts for 1 tag with exclusion" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaa bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post1], "aaa -bbb")
    end

    should "return posts for 1 tag with a pattern" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaab bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2, post1], "a*")
    end

    should "return posts for 2 tags, one with a pattern" do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaab bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2], "a* bbb")
    end

    should "return posts for the id:<N> metatag" do
      posts = create_list(:post, 3)

      assert_tag_match([posts[1]], "id:#{posts[1].id}")
      assert_tag_match([posts[2]], "id:>#{posts[1].id}")
      assert_tag_match([posts[0]], "id:<#{posts[1].id}")

      assert_tag_match([posts[2], posts[0]], "-id:#{posts[1].id}")
      assert_tag_match([posts[2], posts[1]], "id:>=#{posts[1].id}")
      assert_tag_match([posts[1], posts[0]], "id:<=#{posts[1].id}")
      assert_tag_match([posts[2], posts[0]], "id:#{posts[0].id},#{posts[2].id}")
      assert_tag_match(posts.reverse, "id:#{posts[0].id}..#{posts[2].id}")
    end

    should "return posts for the fav:<name> metatag" do
      users = create_list(:user, 2)
      posts = users.map do |u|
        as(u) do
          post = create(:post, tag_string: "abc")
          FavoriteManager.add!(user: u, post: post)
          post
        end
      end

      assert_tag_match([posts[0]], "fav:#{users[0].name}")
      assert_tag_match([posts[1]], "-fav:#{users[0].name}")
    end

    should "return posts for the pool:<name> metatag" do
      create(:pool, name: "test_a")
      create(:pool, name: "test_b")
      post1 = create(:post, tag_string: "pool:test_a")
      post2 = create(:post, tag_string: "pool:test_b")

      assert_tag_match([post1], "pool:test_a")
      assert_tag_match([post2], "-pool:test_a")
      assert_tag_match([], "-pool:test_a -pool:test_b")

      assert_tag_match([post2, post1], "pool:any")
      assert_tag_match([], "pool:none")
    end

    should "return posts for the parent:<N> metatag" do
      parent = create(:post)
      child = create(:post, tag_string: "parent:#{parent.id}")

      assert_tag_match([parent], "parent:none")
      assert_tag_match([child], "-parent:none")
      assert_tag_match([child], "parent:#{parent.id}")

      assert_tag_match([child], "child:none")
      assert_tag_match([parent], "child:any")
    end

    should "return posts for the user:<name> metatag" do
      users = create_list(:user, 2)
      posts = users.map { |u| create(:post, uploader: u) }

      assert_tag_match([posts[0]], "user:#{users[0].name}")
      assert_tag_match([posts[1]], "-user:#{users[0].name}")
    end

    should "return posts for the approver:<name> metatag" do
      users = create_list(:user, 2)
      posts = users.map { |u| create(:post, approver: u) }
      posts << create(:post, approver: nil)

      assert_tag_match([posts[0]], "approver:#{users[0].name}")
      assert_tag_match([posts[2], posts[1]], "-approver:#{users[0].name}")
      assert_tag_match([posts[1], posts[0]], "approver:any")
      assert_tag_match([posts[2]], "approver:none")
    end

    should "return posts for the commenter:<name> metatag" do
      users = create_list(:user, 2, created_at: 2.weeks.ago)
      posts = create_list(:post, 2)
      comms = users.zip(posts).map { |u, p| as(u) { create(:comment, post: p) } }

      assert_tag_match([posts[0]], "commenter:#{users[0].name}")
      assert_tag_match([posts[1]], "commenter:#{users[1].name}")
    end

    should "return posts for the commenter:<any|none> metatag" do
      posts = create_list(:post, 2)
      create(:comment, post: posts[0], is_hidden: false)
      create(:comment, post: posts[1], is_hidden: true)

      assert_tag_match([posts[0]], "commenter:any")
      assert_tag_match([posts[1]], "commenter:none")
    end

    should "return posts for the noter:<name> metatag" do
      users = create_list(:user, 2)
      posts = create_list(:post, 2)
      notes = users.zip(posts).map { |u, p| create(:note, creator: u, post: p) }

      assert_tag_match([posts[0]], "noter:#{users[0].name}")
      assert_tag_match([posts[1]], "noter:#{users[1].name}")
    end

    should "return posts for the noter:<any|none> metatag" do
      posts = create_list(:post, 2)
      create(:note, post: posts[0], is_active: true)
      create(:note, post: posts[1], is_active: false)

      assert_tag_match([posts[0]], "noter:any")
      assert_tag_match([posts[1]], "noter:none")
    end

    should "return posts for the description:<text> metatag" do
      posts = create_list(:post, 2)
      posts[0].update_attribute(:description, 'abc')
      posts[1].update_attribute(:description, 'efg')

      assert_tag_match([posts[0]], "description:abc")
      assert_tag_match([posts[1]], "description:efg")
    end

    should "return posts for the date:<d> metatag" do
      post = create(:post, created_at: Time.parse("2017-01-01 12:00"))

      assert_tag_match([post], "date:2017-01-01")
    end

    should "return posts for the age:<n> metatag" do
      post = create(:post)

      assert_tag_match([post], "age:<60")
      assert_tag_match([post], "age:<60s")
      assert_tag_match([post], "age:<1mi")
      assert_tag_match([post], "age:<1h")
      assert_tag_match([post], "age:<1d")
      assert_tag_match([post], "age:<1w")
      assert_tag_match([post], "age:<1mo")
      assert_tag_match([post], "age:<1y")
    end

    should "return posts for the ratio:<x:y> metatag" do
      post = create(:post, image_width: 1000, image_height: 500)

      assert_tag_match([post], "ratio:2:1")
      assert_tag_match([post], "ratio:2.0")
    end

    should "return posts for the status:<type> metatag" do
      pending = create(:post, is_pending: true)
      flagged = create(:post, is_flagged: true)
      deleted = create(:post, is_deleted: true)
      all = [deleted, flagged, pending]

      assert_tag_match([flagged, pending], "status:modqueue")
      assert_tag_match([pending], "status:pending")
      assert_tag_match([flagged], "status:flagged")
      assert_tag_match([deleted], "status:deleted")
      assert_tag_match([], "status:active")
      assert_tag_match(all, "status:any")
      assert_tag_match(all, "status:all")

      # TODO: These don't quite make sense, what should hide deleted posts and what shouldn't?
      assert_tag_match(all - [deleted, flagged, pending], "-status:modqueue")
      assert_tag_match(all - [deleted, pending], "-status:pending")
      assert_tag_match(all - [deleted, flagged], "-status:flagged")

      assert_tag_match(all - [deleted], "-status:deleted")
      assert_tag_match(all, "-status:active")
    end

    should "return posts for the filetype:<ext> metatag" do
      png = create(:post, file_ext: "png")
      jpg = create(:post, file_ext: "jpg")

      assert_tag_match([png], "filetype:png")
      assert_tag_match([jpg], "-filetype:png")
    end

    should "return posts for the tagcount:<n> metatags" do
      post = create(:post, tag_string: "artist:wokada copyright:vocaloid char:hatsune_miku twintails")

      assert_tag_match([post], "tagcount:4")
      assert_tag_match([], "tagcount:3")
      assert_tag_match([post], "arttags:1")
      assert_tag_match([post], "copytags:1")
      assert_tag_match([post], "chartags:1")
      assert_tag_match([post], "gentags:1")
      assert_tag_match([], "gentags:0")
    end

    should "return posts for the md5:<md5> metatag" do
      post1 = create(:post, md5: "abcd")
      post2 = create(:post)

      assert_tag_match([post1], "md5:abcd")
    end

    should "return posts for a source search" do
      post1 = create(:post, source: "abcd")
      post2 = create(:post, source: "abcdefg")
      post3 = create(:post, source: "")

      assert_tag_match([post2], "source:abcde")
      assert_tag_match([post3, post1], "-source:abcde")

      assert_tag_match([post3], "source:none")
      assert_tag_match([post2, post1], "-source:none")
    end

    # TODO: Known broken. Need to normalize source during search and before index to fix bug with index creation.
    should_eventually "return posts for a case insensitive source search" do
      post1 = create(:post, source: "ABCD")
      post2 = create(:post, source: "1234")

      assert_tag_match([post1], "source:*abcd")
    end

    should "return posts for a pixiv source search" do
      url = "http://i1.pixiv.net/img123/img/artist-name/789.png"
      post = create(:post, source: url)

      assert_tag_match([post], "source:*.pixiv.net/img*/artist-name/*")
      assert_tag_match([],     "source:*.pixiv.net/img*/artist-fake/*")
      assert_tag_match([post], "source:https://*.pixiv.net/img*/img/artist-name/*")
      assert_tag_match([],     "source:https://*.pixiv.net/img*/img/artist-fake/*")
    end

    should "return posts for a rating:<s|q|e> metatag" do
      s = create(:post, rating: "s")
      q = create(:post, rating: "q")
      e = create(:post, rating: "e")
      all = [e, q, s]

      assert_tag_match([s], "rating:s")
      assert_tag_match([q], "rating:q")
      assert_tag_match([e], "rating:e")

      assert_tag_match(all - [s], "-rating:s")
      assert_tag_match(all - [q], "-rating:q")
      assert_tag_match(all - [e], "-rating:e")
    end

    should "return posts for a locked:<rating|note|status> metatag" do
      rating_locked = create(:post, is_rating_locked: true)
      note_locked   = create(:post, is_note_locked: true)
      status_locked = create(:post, is_status_locked: true)
      all = [status_locked, note_locked, rating_locked]

      assert_tag_match([rating_locked], "locked:rating")
      assert_tag_match([note_locked], "locked:note")
      assert_tag_match([status_locked], "locked:status")

      assert_tag_match(all - [rating_locked], "-locked:rating")
      assert_tag_match(all - [note_locked], "-locked:note")
      assert_tag_match(all - [status_locked], "-locked:status")
    end

    should "return posts for a upvote:<user>, downvote:<user> metatag" do
      old_user = create(:mod_user, created_at: 5.days.ago)
      as(old_user) do
        upvoted   = create(:post, tag_string: "abc")
        downvoted = create(:post, tag_string: "abc")
        VoteManager.vote!(user: CurrentUser.user, post: upvoted, score: 1)
        VoteManager.vote!(user: CurrentUser.user, post: downvoted, score: -1)

        assert_tag_match([upvoted],   "upvote:#{CurrentUser.name}")
        assert_tag_match([downvoted], "downvote:#{CurrentUser.name}")
      end
    end

    # FIXME: This test fails randomly at different assertions
    should_eventually "return posts ordered by a particular attribute" do
      posts = (1..2).map do |n|
        tags = ["tagme", "gentag1 gentag2 artist:arttag char:chartag copy:copytag"]

        p = create(
          :post,
          score: n,
          fav_count: n,
          file_size: 1.megabyte * n,
          # posts[0] is portrait, posts[1] is landscape. posts[1].mpixels > posts[0].mpixels.
          image_height: 100*n*n,
          image_width: 100*(3-n)*n,
          tag_string: tags[n-1],
        )

        create(:comment, post: p, do_not_bump_post: false)
        create(:note, post: p)
        p
      end

      create(:note, post: posts.second)

      assert_tag_match(posts.reverse, "order:id_desc")
      assert_tag_match(posts.reverse, "order:score")
      assert_tag_match(posts.reverse, "order:favcount")
      assert_tag_match(posts.reverse, "order:change")
      assert_tag_match(posts.reverse, "order:comment")
      assert_tag_match(posts.reverse, "order:comment_bumped")
      assert_tag_match(posts.reverse, "order:note")
      assert_tag_match(posts.reverse, "order:mpixels")
      assert_tag_match(posts.reverse, "order:portrait")
      assert_tag_match(posts.reverse, "order:filesize")
      assert_tag_match(posts.reverse, "order:tagcount")
      assert_tag_match(posts.reverse, "order:gentags")
      assert_tag_match(posts.reverse, "order:arttags")
      assert_tag_match(posts.reverse, "order:chartags")
      assert_tag_match(posts.reverse, "order:copytags")
      assert_tag_match(posts.reverse, "order:rank")
      assert_tag_match(posts.reverse, "order:note_count")
      assert_tag_match(posts.reverse, "order:note_count_desc")
      assert_tag_match(posts.reverse, "order:notes")
      assert_tag_match(posts.reverse, "order:notes_desc")

      assert_tag_match(posts, "order:id_asc")
      assert_tag_match(posts, "order:score_asc")
      assert_tag_match(posts, "order:favcount_asc")
      assert_tag_match(posts, "order:change_asc")
      assert_tag_match(posts, "order:comment_asc")
      assert_tag_match(posts, "order:comment_bumped_asc")
      assert_tag_match(posts, "order:note_asc")
      assert_tag_match(posts, "order:mpixels_asc")
      assert_tag_match(posts, "order:landscape")
      assert_tag_match(posts, "order:filesize_asc")
      assert_tag_match(posts, "order:tagcount_asc")
      assert_tag_match(posts, "order:gentags_asc")
      assert_tag_match(posts, "order:arttags_asc")
      assert_tag_match(posts, "order:chartags_asc")
      assert_tag_match(posts, "order:copytags_asc")
      assert_tag_match(posts, "order:note_count_asc")
      assert_tag_match(posts, "order:notes_asc")
    end

    should "return posts for order:comment_bumped" do
      post1 = create(:post)
      post2 = create(:post)
      post3 = create(:post)

      as(create(:privileged_user)) do
        create(:comment, post: post1)
        create(:comment, post: post2, do_not_bump_post: true)
        create(:comment, post: post3)
      end

      assert_tag_match([post3, post1], "order:comment_bumped")
      assert_tag_match([post1, post3], "order:comment_bumped_asc")

      create(:comment, post: post2)

      assert_tag_match([post2, post3, post1], "order:comment_bumped")
      assert_tag_match([post1, post3, post2], "order:comment_bumped_asc")
    end

    should "return posts for a filesize search" do
      post = create(:post, file_size: 1.megabyte)

      assert_tag_match([post], "filesize:1mb")
      assert_tag_match([post], "filesize:1000kb")
      assert_tag_match([post], "filesize:1048576b")
    end

    should "not count free tags against the user's search limit" do
      post1 = create(:post, tag_string: "aaa bbb rating:s")

      Danbooru.config.expects(:is_unlimited_tag?).with("rating:s").once.returns(true)
      Danbooru.config.expects(:is_unlimited_tag?).with(anything).twice.returns(false)
      assert_tag_match([post1], "aaa bbb rating:s")
    end

    should "succeed for exclusive tag searches with no other tag" do
      post1 = create(:post, rating: "s", tag_string: "aaa")
      assert_nothing_raised do
        relation = Post.tag_match("-aaa")
      end
    end

    should "succeed for exclusive tag searches combined with a metatag" do
      post1 = create(:post, rating: "s", tag_string: "aaa")
      assert_nothing_raised do
        relation = Post.tag_match("-aaa id:>0")
      end
    end

    should "return posts for replacements" do
      assert_tag_match([], "pending_replacements:true")
      assert_tag_match([], "pending_replacements:false")
      post = create(:post)
      replacement = create(:png_replacement, creator: @user, post: post)
      assert_tag_match([post], "pending_replacements:true")
    end

    should "return no posts when the replacement is not pending anymore" do
      post1 = create(:post)
      upload = UploadService.new(attributes_for(:upload).merge(file: fixture_file_upload("test.gif"), uploader: @user, tag_string: "tst")).start!
      post2 = upload.post
      post3 = create(:post)
      post4 = create(:post)
      replacement1 = create(:png_replacement, creator: @user, post: post1)
      replacement1.reject!
      replacement2 = create(:png_replacement, creator: @user, post: post2)
      replacement2.approve!(penalize_current_uploader: true)
      replacement3 = create(:jpg_replacement, creator: @user, post: post3)
      promoted_post = replacement3.promote!.post
      replacement4 = create(:webm_replacement, creator: @user, post: post4)
      replacement4.destroy!

      assert_tag_match([], "pending_replacements:true")
      assert_tag_match([promoted_post, post4, post3, post2, post1], "pending_replacements:false")
    end
  end

  context "Voting:" do
    should "not allow duplicate votes" do
      user = create(:privileged_user)
      post = create(:post)
      as(user) do
        assert_nothing_raised { VoteManager.vote!(user: user, post: post, score: 1) }
        # Need unvote is returned upon duplicates that are accounted for.
        assert_equal(:need_unvote, VoteManager.vote!(user: user, post: post, score: 1) )
        post.reload
        assert_equal(1, PostVote.count)
        assert_equal(1, post.score)
      end
    end

    should "allow undoing of votes" do
      user = create(:privileged_user, created_at: 7.days.ago)
      post = create(:post)

      # We deliberately don't call post.reload until the end to verify that
      # post.unvote! returns the correct score even when not forcibly reloaded.
      as(user) do
        VoteManager.vote!(post: post, user: user, score: 1)
        assert_equal(1, post.score)

        VoteManager.unvote!(post: post, user: user)
        assert_equal(0, post.score)

        assert_nothing_raised { VoteManager.vote!(post: post, user: user, score: -1) }
        assert_equal(-1, post.score)

        VoteManager.unvote!(post: post, user: user)
        assert_equal(0, post.score)

        assert_nothing_raised { VoteManager.vote!(post: post, user: user, score: 1) }
        assert_equal(1, post.score)

        post.reload
        assert_equal(1, post.score)
      end
    end
  end

  # TODO: These are pretty messed up, both structurally, and expectation wise.
  # New codebase uses fewer cached items, and the keys are different because of -status:deleted default
  # Most of these need major refactoring.
  # context "Counting:" do
  #   context "Creating a post" do
  #     setup do
  #       create(:tag_alias, antecedent_name: "alias", consequent_name: "aaa")
  #       create(:post, tag_string: "aaa", score: 42)
  #     end
  #
  #     context "a single metatag" do
  #       should "return the correct cached count" do
  #         build(:tag, name: "score:42", post_count: -100).save(validate: false)
  #         Post.set_count_in_cache("score:42", 100)
  #
  #         assert_equal(100, Post.fast_count("score:42"))
  #       end
  #
  #       should "return the correct cached count for a pool:<id> search" do
  #         build(:tag, name: "pool:1234", post_count: -100).save(validate: false)
  #         Post.set_count_in_cache("pool:1234", 100)
  #
  #         assert_equal(100, Post.fast_count("pool:1234"))
  #       end
  #     end
  #
  #     context "a multi-tag search" do
  #       should "return the cached count, if it exists" do
  #         Post.set_count_in_cache("aaa score:42", 100)
  #         assert_equal(100, Post.fast_count("aaa score:42"))
  #       end
  #
  #       should "return the true count, if not cached" do
  #         assert_equal(1, Post.fast_count("aaa score:42"))
  #       end
  #
  #       should "set the expiration time" do
  #         Cache.expects(:put).with(Post.count_cache_key("aaa score:42"), 1, 180)
  #         Post.fast_count("aaa score:42")
  #       end
  #     end
  #
  #     context "a blank search" do
  #       should "should execute a search" do
  #         Cache.delete(Post.count_cache_key(''))
  #         Post.expects(:fast_count_search).with("", kind_of(Hash)).once.returns(1)
  #         assert_equal(1, Post.fast_count(""))
  #       end
  #
  #       should "set the value in cache" do
  #         Post.expects(:set_count_in_cache).with("", kind_of(Integer)).once
  #         Post.fast_count("")
  #       end
  #
  #       context "with a primed cache" do
  #         setup do
  #           Cache.write(Post.count_cache_key(''), "100")
  #         end
  #
  #         should "fetch the value from the cache" do
  #           assert_equal(100, Post.fast_count(""))
  #         end
  #       end
  #
  #       should "translate an alias" do
  #         assert_equal(1, Post.fast_count("alias"))
  #       end
  #
  #       should "return 0 for a nonexisting tag" do
  #         assert_equal(0, Post.fast_count("bbb"))
  #       end
  #
  #       context "in safe mode" do
  #         setup do
  #           CurrentUser.stubs(:safe_mode?).returns(true)
  #           create(:post, rating: "s")
  #         end
  #
  #         should "work for a blank search" do
  #           assert_equal(1, Post.fast_count(""))
  #         end
  #
  #         should "work for a nil search" do
  #           assert_equal(1, Post.fast_count(nil))
  #         end
  #
  #         should "not fail for a two tag search by a member" do
  #           post1 = create(:post, tag_string: "aaa bbb rating:s")
  #           post2 = create(:post, tag_string: "aaa bbb rating:e")
  #
  #           Danbooru.config.expects(:is_unlimited_tag?).with("rating:s").once.returns(true)
  #           Danbooru.config.expects(:is_unlimited_tag?).with(anything).twice.returns(false)
  #           assert_equal(1, Post.fast_count("aaa bbb"))
  #         end
  #
  #         should "set the value in cache" do
  #           Post.expects(:set_count_in_cache).with("rating:s", kind_of(Integer)).once
  #           Post.fast_count("")
  #         end
  #
  #         context "with a primed cache" do
  #           setup do
  #             Cache.write(Post.count_cache_key('rating:s'), "100")
  #           end
  #
  #           should "fetch the value from the cache" do
  #             assert_equal(100, Post.fast_count(""))
  #           end
  #         end
  #       end
  #     end
  #   end
  # end

  context "Reverting: " do
    context "a post that is rating locked" do
      setup do
        @post = create(:post, rating: "s")
        @post.update(rating: "q", is_rating_locked: true)
      end

      should "not revert the rating" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Rating is locked and cannot be changed. Unlock the post first."], @post.errors.full_messages)
        assert_equal(@post.versions.last.rating, @post.reload.rating)
      end

      should "revert the rating after unlocking" do
        @post.update(rating: "e", is_rating_locked: false)
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.rating, @post.rating)
      end
    end

    context "a post that has been updated" do
      setup do
        @post = create(:post, rating: "q", tag_string: "aaa", source: "")
        @post.reload
        @post.update(:tag_string => "aaa bbb ccc ddd")
        @post.reload
        @post.update(:tag_string => "bbb xxx yyy", :source => "xyz")
        @post.reload
        @post.update(:tag_string => "bbb mmm yyy", :source => "abc")
        @post.reload
      end

      context "and then reverted to an early version" do
        setup do
          @version = @post.versions[1]
          @post.revert_to!(@version)
          @post.reload
        end

        should "correctly revert all fields" do
          assert_equal("aaa bbb ccc ddd", @post.tag_string)
          assert_equal("", @post.source)
          assert_equal("q", @post.rating)
          assert_equal("Revert to version #{@version.version}", @post.versions.last.reason)
        end
      end

      context "and then reverted to a later version" do
        setup do
          @post.revert_to(@post.versions[-2])
        end

        should "correctly revert all fields" do
          assert_equal("bbb xxx yyy", @post.tag_string)
          assert_equal("xyz", @post.source)
          assert_equal("q", @post.rating)
        end
      end
    end
  end

  context "URLs:" do
    should "generate the correct urls for animated gifs" do
      @post = build(:post, md5: "deadbeef", file_ext: "gif", tag_string: "animated_gif")

      assert_equal("#{Danbooru.config.hostname}/data/preview/deadbeef.jpg", @post.preview_file_url)

      assert_equal("#{Danbooru.config.hostname}/data/deadbeef.gif", @post.large_file_url)
      assert_equal("#{Danbooru.config.hostname}/data/deadbeef.gif", @post.file_url)
    end
  end

  context "Notes:" do
    context "#copy_notes_to" do
      setup do
        @src = create(:post, image_width: 100, image_height: 100, tag_string: "translated partially_translated")
        @dst = create(:post, image_width: 200, image_height: 200, tag_string: "translation_request")

        @src.notes.create(x: 10, y: 10, width: 10, height: 10, body: "test")
        @src.notes.create(x: 10, y: 10, width: 10, height: 10, body: "deleted", is_active: false)
        @src.reload

        @src.copy_notes_to(@dst)
      end

      should "copy notes and tags" do
        assert_equal(1, @dst.notes.active.length)
        assert_equal("low_res partially_translated thumbnail translated", @dst.tag_string)
      end

      should "rescale notes" do
        note = @dst.notes.active.first
        assert_equal([20, 20, 20, 20], [note.x, note.y, note.width, note.height])
      end
    end
  end
end
