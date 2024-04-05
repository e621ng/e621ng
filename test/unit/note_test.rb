# frozen_string_literal: true

require "test_helper"

class NoteTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
    end

    context "for a post that already has a note" do
      setup do
        @post = create(:post)
        @note = create(:note, post: @post)
      end

      context "when the note is deleted the post" do
        setup do
          @note.toggle!(:is_active)
        end

        should "null out its last_noted_at_field" do
          @post.reload
          assert_nil(@post.last_noted_at)
        end
      end
    end

    context "creating a note" do
      setup do
        @post = create(:post, image_width: 1000, image_height: 1000)
      end

      should "not validate if the note is outside the image" do
        @note = build(:note, x: 1001, y: 500, post: @post)
        @note.save
        assert_equal(["Note must be inside the image"], @note.errors.full_messages)
      end

      should "not validate if the note is larger than the image" do
        @note = build(:note, x: 500, y: 500, height: 501, width: 500, post: @post)
        @note.save
        assert_equal(["Note must be inside the image"], @note.errors.full_messages)
      end

      should "not validate if the post does not exist" do
        @note = build(:note, x: 500, y: 500, post_id: -1)
        @note.save
        assert_match(/Post must exist/, @note.errors.full_messages.join)
      end

      should "not validate if the body is blank" do
        @note = build(:note, body: "   ")

        assert_equal(false, @note.valid?)
        assert_equal(["Body can't be blank"], @note.errors.full_messages)
      end

      should "create a version" do
        assert_difference("NoteVersion.count", 1) do
          @note = create(:note, post: @post)
        end

        assert_equal(1, @note.versions.count)
        assert_equal(@note.body, @note.versions.first.body)
        assert_equal(1, @note.version)
        assert_equal(1, @note.versions.first.version)
        assert_equal(@user.id, @note.versions.first.updater_id)
        assert_equal(CurrentUser.ip_addr, @note.versions.first.updater_ip_addr.to_s)
      end

      should "update the post's last_noted_at field" do
        assert_nil(@post.last_noted_at)
        @note = create(:note, post: @post)
        @post.reload
        assert_equal(@post.last_noted_at, @note.updated_at)
      end

      context "for a note-locked post" do
        setup do
          @post.update_attribute(:is_note_locked, true)
        end

        should "fail" do
          assert_difference("Note.count", 0) do
            @note = build(:note, post: @post)
            @note.save
          end
          assert_equal(["Post is note locked"], @note.errors.full_messages)
        end
      end
    end

    context "updating a note" do
      setup do
        @post = create(:post, image_width: 1000, image_height: 1000)
        @note = create(:note, post: @post)
      end

      should "increment the updater's note_update_count" do
        @user.reload
        assert_difference("@user.note_update_count", 1) do
          @note.update(:body => "zzz")
          @user.reload
        end
      end

      should "update the post's last_noted_at field" do
        assert_equal(@post.last_noted_at, @note.updated_at)
        @note.update(x: 500)
        @post.reload
        assert_equal(@post.last_noted_at, @note.updated_at)
      end

      should "create a version" do
        assert_difference("NoteVersion.count", 1) do
          @note.update(body: "fafafa")
        end
        assert_equal(2, @note.versions.count)
        assert_equal(2, @note.versions.last.version)
        assert_equal("fafafa", @note.versions.last.body)
        assert_equal(2, @note.version)
        assert_equal(@user.id, @note.versions.last.updater_id)
        assert_equal(CurrentUser.ip_addr, @note.versions.last.updater_ip_addr.to_s)
      end

      context "for a note-locked post" do
        setup do
          @post.update_attribute(:is_note_locked, true)
        end

        should "fail" do
          @note.update(:x => 500)
          assert_equal(["Post is note locked"], @note.errors.full_messages)
        end
      end

      context "without making any changes" do
        should "not create a new version" do
          assert_no_difference("@note.versions.count") do
            @note.save
          end
        end
      end
    end

    context "when notes have been vandalized by one user" do
      setup do
        @vandal = create(:user)
        @note = create(:note, x: 5, y: 5)
        as(@vandal) do
          @note.update(:x => 10, :y => 10)
        end
      end

      context "the act of undoing all changes by that user" do
        should "revert any affected notes" do
          assert_equal(2, NoteVersion.count)
          assert_equal([1, 2], @note.versions.map(&:version))
          assert_equal([@user.id, @vandal.id], @note.versions.map(&:updater_id))
          Note.undo_changes_by_user(@vandal.id)
          @note.reload
          assert_equal([1, 3], @note.versions.map(&:version))
          assert_equal([@user.id, @user.id], @note.versions.map(&:updater_id))
          assert_equal(5, @note.x)
          assert_equal(5, @note.y)
        end
      end
    end

    context "searching for a note" do
      setup do
        @note = create(:note, body: "aaa")
      end

      context "where the body contains the string 'aaa'" do
        should "return a hit" do
          assert_equal(1, Note.search(body_matches: "aaa").count)
        end
      end

      context "where the body contains the string 'bbb'" do
        should "return no hits" do
          assert_equal(0, Note.search(body_matches: "bbb").count)
        end
      end
    end
  end
end
