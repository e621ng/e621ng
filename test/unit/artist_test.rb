# frozen_string_literal: true

require "test_helper"

class ArtistTest < ActiveSupport::TestCase
  def assert_artist_found(expected_name, source_url)
    artists = Artist.find_artists(source_url).to_a

    assert_equal(1, artists.size)
    assert_equal(expected_name, artists.first.name, "Testing URL: #{source_url}")
  end

  def assert_artist_not_found(source_url)
    artists = Artist.find_artists(source_url).to_a
    assert_equal(0, artists.size, "Testing URL: #{source_url}")
  end

  context "An artist" do
    setup do
      user = create(:user, created_at: 1.month.ago)
      CurrentUser.user = user
    end

    should "parse inactive urls" do
      @artist = Artist.create(name: "blah", url_string: "-http://monet.com")
      assert_equal(["-http://monet.com"], @artist.urls.map(&:to_s))
      assert_not(@artist.urls[0].is_active?)
    end

    should "not allow duplicate active+inactive urls" do
      @artist = Artist.create(name: "blah", url_string: "-http://monet.com\nhttp://monet.com")
      assert_equal(1, @artist.urls.count)
      assert_equal(["-http://monet.com"], @artist.urls.map(&:to_s))
      assert_not(@artist.urls[0].is_active?)
    end

    should "allow deactivating a url" do
      @artist = Artist.create(name: "blah", url_string: "http://monet.com")
      @artist.update(url_string: "-http://monet.com")
      assert_equal(1, @artist.urls.count)
      assert_not(@artist.urls[0].is_active?)
    end

    should "allow activating a url" do
      @artist = Artist.create(name: "blah", url_string: "-http://monet.com")
      @artist.update(url_string: "http://monet.com")
      assert_equal(1, @artist.urls.count)
      assert(@artist.urls[0].is_active?)
    end

    context "with an invalid name" do
      subject { build(:artist) }

      should_not allow_value("-blah").for(:name)
      should_not allow_value("_").for(:name)
      should_not allow_value("").for(:name)
    end

    should "create a new wiki page to store any note information" do
      artist = nil
      assert_difference("WikiPage.count") do
        artist = create(:artist, name: "aaa", notes: "testing")
      end
      assert_equal("testing", artist.notes)
      assert_equal("testing", artist.wiki_page.body)
      assert_equal(artist.name, artist.wiki_page.title)
    end

    should "update the wiki page when notes are assigned" do
      artist = create(:artist, name: "aaa", notes: "testing")
      artist.update_attribute(:notes, "kokoko")
      artist.reload
      assert_equal("kokoko", artist.notes)
      assert_equal("kokoko", artist.wiki_page.body)
    end

    should "normalize its name" do
      artist = create(:artist, name: "  AAA BBB  ")
      assert_equal("aaa_bbb", artist.name)
    end

    should "resolve ambiguous urls" do
      bobross = create(:artist, name: "bob_ross", url_string: "http://artists.com/bobross/image.jpg")
      bob = create(:artist, name: "bob", url_string: "http://artists.com/bob/image.jpg")
      assert_artist_found("bob", "http://artists.com/bob/test.jpg")
    end

    should "parse urls" do
      artist = create(:artist, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg http://aaa.com")
      artist.reload
      assert_equal(["http://aaa.com", "http://rembrandt.com/test.jpg"], artist.urls.map(&:to_s).sort)
    end

    should "not allow invalid urls" do
      artist = build(:artist, url_string: "blah")
      assert_equal(false, artist.valid?)
      assert_equal(["'blah' must begin with http:// or https:// "], artist.errors["urls.url"])
    end

    should "allow fixing invalid urls" do
      artist = build(:artist)
      artist.urls << build(:artist_url, url: "www.example.com", normalized_url: "www.example.com")
      artist.save(validate: false)

      artist.update(url_string: "http://www.example.com")
      assert_equal(true, artist.valid?)
      assert_equal("http://www.example.com", artist.urls.map(&:to_s).join)
    end

    should "make sure old urls are deleted" do
      artist = create(:artist, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg")
      artist.url_string = "http://not.rembrandt.com/test.jpg"
      artist.save
      artist.reload
      assert_equal(["http://not.rembrandt.com/test.jpg"], artist.urls.map(&:to_s).sort)
    end

    should "not delete urls that have not changed" do
      artist = create(:artist, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg")
      old_url_ids = ArtistUrl.order("id").pluck(&:id)
      artist.url_string = "http://rembrandt.com/test.jpg"
      artist.save
      assert_equal(old_url_ids, ArtistUrl.order("id").pluck(&:id))
    end

    should "ignore pixiv.net/ and pixiv.net/img/ url matches" do
      a1 = create(:artist, name: "yomosaka", url_string: "http://i2.pixiv.net/img18/img/evazion/14901720.png")
      a2 = create(:artist, name: "niwatazumi_bf", url_string: "http://i2.pixiv.net/img18/img/evazion/14901720_big_p0.png")
      assert_artist_not_found("http://i2.pixiv.net/img28/img/kyang692/35563903.jpg")
    end

    should "find matches by url" do
      a1 = create(:artist, name: "rembrandt", url_string: "http://rembrandt.com/x/test.jpg")
      a2 = create(:artist, name: "subway", url_string: "http://subway.com/x/test.jpg")
      a3 = create(:artist, name: "minko", url_string: "https://minko.com/x/test.jpg")

      begin
        assert_artist_found("rembrandt", "http://rembrandt.com/x/test.jpg")
        assert_artist_found("rembrandt", "http://rembrandt.com/x/another.jpg")
        assert_artist_not_found("http://nonexistent.com/test.jpg")
        assert_artist_found("minko", "https://minko.com/x/test.jpg")
        assert_artist_found("minko", "http://minko.com/x/test.jpg")
      rescue Net::OpenTimeout
        skip "network failure"
      end
    end

    should "be case-insensitive to domains when finding matches by url" do
      a1 = create(:artist, name: "bkub", url_string: "http://BKUB.example.com")
      assert_artist_found(a1.name, "http://bkub.example.com")
    end

    should "not find duplicates" do
      create(:artist, name: "warhol", url_string: "http://warhol.com/x/a/image.jpg\nhttp://warhol.com/x/b/image.jpg")
      assert_artist_found("warhol", "http://warhol.com/x/test.jpg")
    end

    should "not include duplicate urls" do
      artist = create(:artist, url_string: "http://foo.com http://foo.com")
      assert_equal(["http://foo.com"], artist.url_array)
    end

    should "hide deleted artists" do
      as(create(:admin_user)) do
        create(:artist, name: "warhol", url_string: "http://warhol.com/a/image.jpg", is_active: false)
      end
      assert_artist_not_found("http://warhol.com/a/image.jpg")
    end

    context "when finding tumblr artists" do
      setup do
        create(:artist, name: "ilya_kuvshinov", url_string: "http://kuvshinov-ilya.tumblr.com")
        create(:artist, name: "j.k.", url_string: "https://jdotkdot5.tumblr.com")
      end

      should "find the artist" do
        assert_artist_found("ilya_kuvshinov", "http://kuvshinov-ilya.tumblr.com/post/168641755845")
        assert_artist_found("j.k.", "https://jdotkdot5.tumblr.com/post/168276640697")
      end

      should "return nothing for unknown tumblr artists" do
        assert_artist_not_found("https://peptosis.tumblr.com/post/168162082005")
      end
    end

    should "normalize its other names" do
      artist = create(:artist, name: "a1", other_names: "a1 aaa aaa AAA bbb ccc_ddd")
      assert_equal("aaa bbb ccc_ddd", artist.other_names_string)
    end

    should "search on its name should return results" do
      create(:artist, name: "artist")

      assert_not_nil(Artist.search(name: "artist").first)
      assert_not_nil(Artist.search(any_name_matches: "artist").first)
      assert_not_nil(Artist.search(any_name_matches: "*art*").first)
    end

    should "search on other names should return matches" do
      create(:artist, name: "artist", other_names_string: "aaa ccc_ddd")

      assert_nil(Artist.search(any_other_name_like: "*artist*").first)
      assert_not_nil(Artist.search(any_other_name_like: "*aaa*").first)
      assert_not_nil(Artist.search(any_other_name_like: "*ccc_ddd*").first)
      assert_not_nil(Artist.search(name: "artist").first)
      assert_not_nil(Artist.search(any_name_matches: "aaa").first)
      assert_not_nil(Artist.search(any_name_matches: "*a*").first)
    end

    should "search on group name and return matches" do
      cat_or_fish = create(:artist, name: "cat_or_fish")
      create(:artist, name: "yuu", group_name: "cat_or_fish")

      assert_equal("yuu", cat_or_fish.member_names)
      assert_not_nil(Artist.search(group_name: "cat_or_fish").first)
      assert_not_nil(Artist.search(any_name_matches: "cat_or_fish").first)
      assert_not_nil(Artist.search(any_name_matches: "*cat*").first)
    end

    should "search on url and return matches" do
      bkub = create(:artist, name: "bkub", url_string: "http://bkub.com")

      assert_equal([bkub.id], Artist.search(url_matches: "bkub").map(&:id))
      assert_equal([bkub.id], Artist.search(url_matches: "*bkub*").map(&:id))
      assert_equal([], Artist.search(url_matches: "*rifyu*").map(&:id))
      assert_equal([bkub.id], Artist.search(url_matches: "http://bkub.com/test.jpg").map(&:id))
    end

    should "search on has_tag and return matches" do
      post = create(:post, tag_string: "bkub")
      bkub = create(:artist, name: "bkub")
      none = create(:artist, name: "none")

      assert_equal(bkub.id, Artist.search(has_tag: "true").first.id)
      assert_equal(none.id, Artist.search(has_tag: "false").first.id)
    end

    should "revert to prior versions" do
      user = create(:user)
      reverter = create(:user)
      artist = nil
      assert_difference("ArtistVersion.count") do
        artist = create(:artist, other_names: "yyy")
      end

      assert_difference("ArtistVersion.count") do
        artist.other_names = "xxx"
        artist.save
      end

      first_version = ArtistVersion.first
      assert_equal(%w[yyy], first_version.other_names)
      artist.revert_to!(first_version)
      artist.reload
      assert_equal(%w[yyy], artist.other_names)
    end

    should "update the category of the tag when created" do
      CurrentUser.user = create(:janitor_user)
      tag = create(:tag, name: "abc")
      artist = create(:artist, name: "abc")
      tag.reload
      assert_equal(Tag.categories.artist, tag.category)
    end

    context "when saving" do
      setup do
        @artist = create(:artist, url_string: "http://foo.com")
      end

      should "create a new version when a url is added" do
        assert_difference("ArtistVersion.count") do
          @artist.update(url_string: "http://foo.com http://bar.com")
          assert_equal(%w[http://bar.com http://foo.com], @artist.versions.last.urls)
        end
      end

      should "create a new version when a url is removed" do
        assert_difference("ArtistVersion.count") do
          @artist.update(url_string: "")
          assert_equal(%w[], @artist.versions.last.urls)
        end
      end

      should "create a new version when a url is marked inactive" do
        assert_difference("ArtistVersion.count") do
          @artist.update(url_string: "-http://foo.com")
          assert_equal(%w[-http://foo.com], @artist.versions.last.urls)
        end
      end

      should "not create a new version when nothing has changed" do
        assert_no_difference("ArtistVersion.count") do
          @artist.save
          assert_equal(%w[http://foo.com], @artist.versions.last.urls)
        end
      end

      should "not save invalid urls" do
        assert_no_difference("ArtistVersion.count") do
          @artist.update(url_string: "http://foo.com www.example.com")
          assert_equal(%w[http://foo.com], @artist.versions.last.urls)
        end
      end
    end

    context "that is deleted" do
      setup do
        @artist = create(:artist, url_string: "https://google.com")
        @artist.update_attribute(:is_active, false)
        @artist.reload
      end

      should "preserve the url string" do
        assert_equal(1, @artist.urls.count)
      end
    end

    context "that is updated" do
      setup do
        @artist = create(:artist, name: "test")
      end

      should "log the correct data when renamed" do
        @artist.update(name: "new_name")
        assert_equal({ "new_name" => "new_name", "old_name" => "test" }, ModAction.last.values)
      end

      should "log the correct data when linked/unlinked" do
        user = create(:user)

        @artist.update(linked_user: user)
        mod_action = ModAction.last
        assert_equal("artist_user_linked", mod_action.action)
        assert_equal({ "artist_page" => @artist.id, "user_id" => user.id }, mod_action.values)

        @artist.update(linked_user: nil)
        mod_action = ModAction.last
        assert_equal("artist_user_unlinked", mod_action.action)
        assert_equal({ "artist_page" => @artist.id, "user_id" => user.id }, mod_action.values)
      end

      should "fail if the user is limited" do
        @artist.url_string = "https://e621.net"
        as(create(:user)) { @artist.save }

        @artist.reload
        assert_equal("https://e621.net", @artist.url_string)

        Danbooru.config.stubs(:disable_throttles?).returns(false)
        Danbooru.config.stubs(:artist_edit_limit).returns(0)

        @artist.url_string = ""
        assert_no_difference(-> { ArtistVersion.count }) do
          as(create(:user)) { @artist.save }
        end

        @artist.reload
        assert_equal("https://e621.net", @artist.url_string)
      end

      should "not change urls when locked" do
        @artist.url_string = "https://e621.net"
        as(create(:user)) { @artist.save }

        @artist.reload
        assert_equal("https://e621.net", @artist.url_string)

        @artist.update_column(:is_locked, true)

        @artist.url_string = "https://e926.net"
        assert_no_difference(-> { ArtistVersion.count }) do
          as(create(:user)) { @artist.save }
        end

        @artist.reload
        assert_equal("https://e621.net", @artist.url_string)
      end

      should "not change notes when locked" do
        @artist.notes = "abababab"
        as(create(:user)) { @artist.save }

        assert_equal("abababab", @artist.wiki_page.body)

        @artist.wiki_page.update_column(:is_locked, true)

        @artist.notes = "babababa"
        assert_no_difference(-> { ArtistVersion.count }) do
          as(create(:user)) { @artist.save }
        end

        assert_equal("abababab", @artist.wiki_page.body)

        assert_equal(["Wiki page is locked"], @artist.errors.full_messages)
      end
    end
  end
end
