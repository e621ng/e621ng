# frozen_string_literal: true

require "test_helper"

class PostEventTest < ActiveSupport::TestCase
  setup do
    travel_to(1.month.ago) do
      @user = create(:user)
      @janitor = create(:janitor_user)
      @admin = create(:admin_user)
    end

    @post2 = create(:post, uploader: @user)
    @post = create(:post, uploader: @user, parent: @post2)
  end

  def assert_post_events_created(user, events, &block)
    count = Array.wrap(events).count
    as user do
      assert_difference(-> { PostEvent.count }, count, &block)
      assert_equal Array.wrap(events).map(&:to_s), PostEvent.last(count).map(&:action)
    end
  end

  # TODO: This test file needs a rewrite. Each of these actions should be in its own test. The context block does not follow best practices.
  context "certain actions" do
    should "create a post event" do
      assert_post_events_created(@janitor, :approved) do
        @post.approve!(@janitor)
      end

      assert_post_events_created(@janitor, :unapproved) do
        @post.unapprove!
      end

      assert_post_events_created(@user, :flag_created) do
        create(:post_flag, post: @post)
      end

      assert_post_events_created(@janitor, :flag_removed) do
        @post.unflag!
      end

      assert_post_events_created(@janitor, :deleted) do
        @post.delete!("reason")
      end

      assert_post_events_created(@janitor, :undeleted) do
        @post.undelete!
      end

      assert_post_events_created(@janitor, [:favorites_moved, :favorites_received]) do
        TransferFavoritesJob.new.perform @post.id, @janitor.id
      end

      assert_post_events_created(@admin, :rating_locked) do
        @post.is_rating_locked = true
        @post.save
      end

      assert_post_events_created(@admin, :rating_unlocked) do
        @post.is_rating_locked = false
        @post.save
      end

      assert_post_events_created(@admin, :status_locked) do
        @post.is_status_locked = true
        @post.save
      end

      assert_post_events_created(@admin, :status_unlocked) do
        @post.is_status_locked = false
        @post.save
      end

      assert_post_events_created(@admin, :comment_locked) do
        @post.is_comment_locked = true
        @post.save
      end

      assert_post_events_created(@admin, :comment_unlocked) do
        @post.is_comment_locked = false
        @post.save
      end

      assert_post_events_created(@admin, :note_locked) do
        @post.is_note_locked = true
        @post.save
      end

      assert_post_events_created(@admin, :note_unlocked) do
        @post.is_note_locked = false
        @post.save
      end

      assert_post_events_created(@janitor, :changed_bg_color) do
        @post.bg_color = "FFFFFF"
        @post.save
      end

      assert_post_events_created(@admin, :expunged) do
        @post.expunge!
      end
    end

    context "replacements" do
      setup do
        upload1 = UploadService.new(attributes_for(:jpg_upload).merge(uploader: @user, tag_string: "tst")).start!
        @post1 = upload1.post
        @replacement1 = create(:png_replacement, creator: @user, post: @post1)
      end

      should "reject" do
        assert_post_events_created(@admin, :replacement_rejected) do
          @replacement1.reject!
        end
      end

      should "approve" do
        assert_post_events_created(@admin, :replacement_accepted) do
          @replacement1.approve! penalize_current_uploader: true
        end
      end

      should "destroy" do
        assert_post_events_created(@admin, :replacement_deleted) do
          @replacement1.destroy!
        end
      end

      context "transfer" do
        setup do
          upload2 = UploadService.new(attributes_for(:large_jpg_upload).merge(uploader: @user, tag_string: "tst")).start!
          @post2 = upload2.post
          @replacement2 = create(:apng_replacement, creator: @user, post: @post2)
        end

        should "transfer" do
          assert_post_events_created(@admin, [:replacement_moved, :replacement_moved]) do
            @replacement1.transfer(@post2)
          end
        end
      end
    end
  end
end
