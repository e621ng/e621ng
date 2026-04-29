# frozen_string_literal: true

require "test_helper"

class PostSetTest < ActiveSupport::TestCase
  context "PostSet" do
    setup do
      @user = create(:user)
      as(@user) do
        @set = create(:post_set)
      end
    end

    should "normalize shortname to lowercase on save" do
      as(@user) do
        ps = build(:post_set, shortname: "MiXeD_Case_Name")
        assert(ps.valid?)
        ps.save!
        assert_equal "mixed_case_name", ps.reload.shortname
      end
    end

    should "update post_count when post_ids changes" do
      as(@user) do
        p1 = create(:post)
        p2 = create(:post)
        @set.post_ids = [p1.id, p2.id]
        @set.save!
        assert_equal 2, @set.reload.post_count
      end
    end

    should "use post_count for is_over_limit? checks" do
      as(@user) do
        # Make the limit very small so the +100 buffer is easy to hit
        Danbooru.config.stubs(:post_set_post_limit).returns(0)

        # Bypass validations/callbacks so we can control post_count precisely
        @set.update_columns(post_ids: (1..100).to_a, post_count: 100)
        assert_not @set.reload.is_over_limit?

        @set.update_columns(post_ids: (1..101).to_a, post_count: 101)
        assert @set.reload.is_over_limit?
      end
    end

    should "validate max posts when exceeding configured limit" do
      as(@user) do
        Danbooru.config.stubs(:post_set_post_limit).returns(2)
        @set.update!(post_ids: [1, 2])

        @set.post_ids = [1, 2, 3]
        assert_not @set.valid?
        assert_includes @set.errors.full_messages.join(" "), "Sets can only have up to"
      end
    end

    should "add and remove posts via array helpers (non-bang) and persist" do
      as(@user) do
        p1 = create(:post)
        p2 = create(:post)

        @set.add([p1.id, p2.id])
        @set.save!
        assert_equal [p1.id, p2.id].sort, @set.reload.post_ids.sort
        assert_equal 2, @set.post_count

        @set.remove([p1.id])
        @set.save!
        assert_equal [p2.id], @set.reload.post_ids
        assert_equal 1, @set.post_count
      end
    end

    should "find sets containing a post via where_has_post" do
      as(@user) do
        p = create(:post)
        @set.update!(post_ids: [p.id])

        matches = PostSet.where_has_post(p.id).to_a
        assert_equal [@set.id], matches.map(&:id)
      end
    end

    should "not duplicate a post when added twice via SQL helper" do
      as(@user) do
        p = create(:post)
        @set.update!(post_ids: [p.id])

        added = @set.process_posts_add!([p.id])
        assert_equal [], added
        assert_equal [p.id], @set.reload.post_ids
        assert_equal 1, @set.post_count
      end
    end

    should "ignore removing a post that isn't in the set via SQL helper" do
      as(@user) do
        existing = create(:post)
        missing = create(:post)
        @set.update!(post_ids: [existing.id])

        removed = @set.process_posts_remove!([missing.id])
        assert_equal [], removed
        assert_equal [existing.id], @set.reload.post_ids
        assert_equal 1, @set.post_count
      end
    end

    should "trigger synchronize after save when post_ids are changed via writer" do
      as(@user) do
        p = create(:post)
        @set.expects(:synchronize).once
        @set.update!(post_ids: [p.id])
      end
    end

    should "not trigger synchronize when using SQL helpers to modify membership" do
      as(@user) do
        p = create(:post)
        @set.expects(:synchronize).never
        added = @set.process_posts_add!([p.id])
        assert_equal [p.id], added
        # Ensure DB state changed without invoking after_save callback
        assert_includes PostSet.find(@set.id).post_ids, p.id
      end
    end

    should "enqueue and cleanup posts after set destroy asynchronously" do
      as(@user) do
        p1 = create(:post)
        p2 = create(:post)
        # Add one-by-one to trigger inline sync for single changes
        @set.add([p1.id])
        @set.add([p2.id])
        # Ensure posts are tagged with the set
        [p1, p2].each do |p|
          p.reload
          assert p.belongs_to_post_set(@set)
        end

        # Expect cleanup job enqueued on destroy
        PostSetCleanupJob.expects(:perform_later).with(:set, @set.id).once
        @set.destroy

        # Simulate job execution inline to verify effect
        PostSetCleanupJob.new.perform(:set, @set.id)
        [p1, p2].each do |p|
          p.reload
          assert_not p.belongs_to_post_set(@set)
        end
      end
    end
  end
end
