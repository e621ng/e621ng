# frozen_string_literal: true

require "test_helper"

class AvoidPostingTest < ActiveSupport::TestCase
  context "An avoid posting entry" do
    setup do
      @bd_user = create(:bd_staff_user)
      CurrentUser.user = @bd_user
      @avoid_posting = create(:avoid_posting)
      @artist = create(:artist, name: @avoid_posting.artist_name)
    end

    should "not require an artist" do
      assert_no_difference("Artist.count") do
        create(:avoid_posting)
      end
    end

    should "create a create modaction" do
      assert_difference("ModAction.count", 1) do
        create(:avoid_posting)
      end

      assert_equal("avoid_posting_create", ModAction.last.action)
    end

    should "create an update modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(details: "test")
      end

      assert_equal("avoid_posting_update", ModAction.last.action)
    end

    should "create a delete modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(is_active: false)
      end

      assert_equal("avoid_posting_delete", ModAction.last.action)
    end

    should "create an undelete modaction" do
      @avoid_posting.update_column(:is_active, false)

      assert_difference("ModAction.count", 1) do
        @avoid_posting.update(is_active: true)
      end

      assert_equal("avoid_posting_undelete", ModAction.last.action)
    end

    should "create a destroy modaction" do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.destroy
      end

      assert_equal("avoid_posting_destroy", ModAction.last.action)
    end

    should "update artist when dnp is renamed" do
      assert_difference("ModAction.count", 2) do
        @avoid_posting.update(artist_name: "another_artist", rename_artist: true)
      end

      assert_equal(%w[avoid_posting_update artist_page_rename], ModAction.last(2).map(&:action))
      assert_equal("another_artist", @avoid_posting.reload.artist_name)
      assert_equal("another_artist", @artist.reload.name)
    end

    should "not update dnp or artist when an artist with the name already exists" do
      name = @artist.name
      new_artist_name = create(:artist).name
      assert_no_difference("ModAction.count") do
        assert_no_difference("ArtistVersion.count") do
          @avoid_posting.update(artist_name: new_artist_name, rename_artist: true)
        end
      end

      assert_equal(name, @avoid_posting.reload.artist_name)
      assert_equal(name, @artist.reload.name)
    end

    should "not update artist if rename_artist=false" do
      name = @artist.name
      assert_difference("ModAction.count", 1) do
        assert_no_difference("ArtistVersion.count") do
          @avoid_posting.update(artist_name: "another_artist", rename_artist: false)
        end
      end

      assert_equal("another_artist", @avoid_posting.reload.artist_name)
      assert_equal(name, @artist.reload.name)
    end

    should "create a version when updated" do
      assert_difference("AvoidPostingVersion.count", 1) do
        @avoid_posting.update(details: "test")
      end

      assert_equal("test", AvoidPostingVersion.last.details)
    end
  end

  context "An artist" do
    setup do
      @bd_user = create(:bd_staff_user)
      CurrentUser.user = @bd_user
      @avoid_posting = create(:avoid_posting)
      @artist = create(:artist, name: @avoid_posting.artist_name)
    end

    should "update dnp when artist is renamed" do
      assert_difference("ModAction.count", 2) do
        @artist.update(name: "another_artist", rename_dnp: true)
      end

      assert_equal(%w[artist_page_rename avoid_posting_update], ModAction.last(2).map(&:action))
      assert_equal("another_artist", @avoid_posting.reload.artist_name)
      assert_equal("another_artist", @artist.reload.name)
    end

    should "not update artist or dnp when an artist with the name already exists" do
      name = @avoid_posting.artist_name
      new_name = create(:avoid_posting).artist_name
      assert_no_difference("ModAction.count") do
        assert_no_difference("AvoidPostingVersion.count") do
          @artist.update(name: new_name, rename_dnp: true)
        end
      end

      assert_equal(name, @avoid_posting.reload.artist_name)
      assert_equal(name, @artist.reload.name)
    end

    should "not update dnp if rename_dnp=false" do
      name = @avoid_posting.artist_name
      assert_difference("ModAction.count", 1) do
        assert_no_difference("AvoidPostingVersion.count") do
          @artist.update(name: "another_artist", rename_dnp: false)
        end
      end

      assert_equal("another_artist", @artist.reload.name)
      assert_equal(name, @avoid_posting.reload.artist_name)
    end

    should "prevent editing name when dnp is active" do
      name = @artist.name
      user = create(:user)
      as(user) do
        @artist.update(name: "another_artist")
      end

      assert_equal(name, @artist.reload.name)
    end

    should "allow creation when on dnp list" do
      dnp = create(:avoid_posting)
      assert_difference("Artist.count", 1) do
        create(:artist, name: dnp.artist_name)
      end
    end
  end
end
