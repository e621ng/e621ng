# frozen_string_literal: true

require "test_helper"

class ArtistsControllerTest < ActionDispatch::IntegrationTest
  context "An artists controller" do
    setup do
      @admin = create(:admin_user)
      @user = create(:user)
      as(@user) do
        @artist = create(:artist, notes: "message")
        @masao = create(:artist, name: "masao", url_string: "http://www.pixiv.net/member.php?id=32777")
        @artgerm = create(:artist, name: "artgerm", url_string: "http://artgerm.deviantart.com/")
      end
    end

    should "get the new page" do
      get_auth new_artist_path, @user
      assert_response :success
    end

    should "get the show_or_new page for an existing artist" do
      get_auth show_or_new_artists_path(name: "masao"), @user
      assert_redirected_to(@masao)
    end

    should "get the show_or_new page for a nonexisting artist" do
      get_auth show_or_new_artists_path(name: "nobody"), @user
      assert_response :success
    end

    should "get the edit page" do
      get_auth edit_artist_path(@artist.id), @user
      assert_response :success
    end

    should "get the show page" do
      get artist_path(@artist.id)
      assert_response :success
    end

    should "get the index page" do
      get artists_path
      assert_response :success
    end

    should "create an artist" do
      attributes = attributes_for(:artist)
      assert_difference("Artist.count", 1) do
        attributes.delete(:is_active)
        post_auth artists_path, @user, params: {artist: attributes}
      end
      artist = Artist.find_by_name(attributes[:name])
      assert_not_nil(artist)
      assert_redirected_to(artist_path(artist.id))
    end

    context "with an artist that has notes" do
      setup do
        as(@admin) do
          @artist = create(:artist, name: "aaa", notes: "testing", url_string: "http://example.com")
        end
        @wiki_page = @artist.wiki_page
        @another_user = create(:user)
      end

      should "update an artist" do
        old_timestamp = @wiki_page.updated_at
        travel_to(1.minute.from_now) do
          put_auth artist_path(@artist.id), @user, params: {artist: {notes: "rex", url_string: "http://example.com\nhttp://monet.com"}}
        end
        @artist.reload
        @wiki_page = @artist.wiki_page
        assert_equal("rex", @artist.notes)
        assert_not_equal(old_timestamp, @wiki_page.updated_at)
        assert_redirected_to(artist_path(@artist.id))
      end

      should "not touch the updater_id and updated_at fields when nothing is changed" do
        old_timestamp = @wiki_page.updated_at
        old_updater_id = @wiki_page.updater_id

        travel_to(1.minute.from_now) do
          as(@another_user) do
            @artist.update(notes: "testing")
          end
        end

        @artist.reload
        @wiki_page = @artist.wiki_page
        assert_in_delta(old_timestamp.to_i, @wiki_page.updated_at.to_i, 1)
        assert_equal(old_updater_id, @wiki_page.updater_id)
      end

      context "when renaming an artist" do
        should "automatically rename the artist's wiki page" do
          assert_difference("WikiPage.count", 0) do
            put_auth artist_path(@artist.id), @user, params: {artist: {name: "bbb", notes: "more testing"}}
          end
          @wiki_page.reload
          assert_equal("bbb", @wiki_page.title)
          assert_equal("more testing", @wiki_page.body)
        end
      end
    end

    should "delete an artist" do
      @janitor = create(:janitor_user)
      delete_auth artist_path(@artist.id), @janitor
      assert_redirected_to(artist_path(@artist.id))
      @artist.reload
      assert_equal(false, @artist.is_active)
    end

    should "undelete an artist" do
      @janitor = create(:janitor_user)
      put_auth artist_path(@artist.id), @janitor, params: {artist: {is_active: true}}
      assert_redirected_to(artist_path(@artist.id))
      assert_equal(true, @artist.reload.is_active)
    end

    context "reverting an artist" do
      should "work" do
        as(@user) do
          @artist.update(name: "xyz")
          @artist.update(name: "abc")
        end
        version = @artist.versions.first
        put_auth revert_artist_path(@artist.id), @user, params: {version_id: version.id}
      end

      should "not allow reverting to a previous version of another artist" do
        as(@user) do
          @artist2 = create(:artist)
        end
        put_auth artist_path(@artist.id), @user, params: {version_id: @artist2.versions.first.id}
        @artist.reload
        assert_not_equal(@artist.name, @artist2.name)
        assert_redirected_to(artist_path(@artist.id))
      end
    end
  end
end
