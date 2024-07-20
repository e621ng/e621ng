# frozen_string_literal: true

require "test_helper"

class ArtistUrlTest < ActiveSupport::TestCase
  def assert_search_equals(results, conditions)
    assert_equal(results.map(&:id), subject.search(conditions).map(&:id))
  end

  context "An artist url" do
    setup do
      CurrentUser.user = create(:user)
    end

    should "allow urls to be marked as inactive" do
      url = create(:artist_url, url: "http://monet.com", is_active: false)
      assert_equal("http://monet.com", url.url)
      assert_equal("http://monet.com/", url.normalized_url)
      assert_equal("-http://monet.com", url.to_s)
    end

    should "disallow invalid urls" do
      url = build(:artist_url, url: "www.example.com")

      assert_equal(false, url.valid?)
      assert_match(/must begin with http/, url.errors.full_messages.join)
    end

    should "always add a trailing slash when normalized" do
      url = create(:artist_url, url: "http://monet.com")
      assert_equal("http://monet.com", url.url)
      assert_equal("http://monet.com/", url.normalized_url)

      url = create(:artist_url, url: "http://monet.com/")
      assert_equal("http://monet.com/", url.url)
      assert_equal("http://monet.com/", url.normalized_url)
    end

    should "normalise https" do
      url = create(:artist_url, url: "https://google.com")
      assert_equal("https://google.com", url.url)
      assert_equal("http://google.com/", url.normalized_url)
    end

    should "normalise domains to lowercase" do
      url = create(:artist_url, url: "https://ArtistName.example.com")
      assert_equal("http://artistname.example.com/", url.normalized_url)
    end

    should "normalize nico seiga artist urls" do
      url = create(:artist_url, url: "http://seiga.nicovideo.jp/user/illust/7017777")
      assert_equal("http://seiga.nicovideo.jp/user/illust/7017777/", url.normalized_url)
    end

    should "normalize hentai foundry artist urls" do
      url = create(:artist_url, url: "http://pictures.hentai-foundry.com/a/AnimeFlux/219123.jpg")
      assert_equal("http://pictures.hentai-foundry.com/a/AnimeFlux/219123.jpg/", url.normalized_url)
    end

    should "normalize pixiv stacc urls" do
      url = create(:artist_url, url: "https://www.pixiv.net/stacc/evazion")
      assert_equal("https://www.pixiv.net/stacc/evazion", url.url)
      assert_equal("http://www.pixiv.net/stacc/evazion/", url.normalized_url)
    end

    should "normalize pixiv fanbox account urls" do
      url = create(:artist_url, url: "http://www.pixiv.net/fanbox/creator/3113804")
      assert_equal("http://www.pixiv.net/fanbox/creator/3113804", url.url)
      assert_equal("http://www.pixiv.net/fanbox/creator/3113804/", url.normalized_url)
    end

    should "normalize https://twitter.com/intent/user?user_id=* urls" do
      url = create(:artist_url, url: "https://twitter.com/intent/user?user_id=2784590030")
      assert_equal("https://twitter.com/intent/user?user_id=2784590030", url.url)
      assert_equal("http://twitter.com/intent/user?user_id=2784590030/", url.normalized_url)
    end
    context "#search method" do
      subject { ArtistUrl }

      should "work" do
        @bkub = create(:artist, name: "bkub", url_string: "https://bkub.com")
        as(create(:admin_user)) do
          @masao = create(:artist, name: "masao", url_string: "-https://masao.com")
        end
        @bkub_url = @bkub.urls.first
        @masao_url = @masao.urls.first

        assert_search_equals([@bkub_url], is_active: true)
        assert_search_equals([@bkub_url], artist: { name: "bkub" })

        assert_search_equals([@bkub_url], url_matches: "*bkub*")

        assert_search_equals([@bkub_url], normalized_url_matches: "*bkub*")
        assert_search_equals([@bkub_url], normalized_url_matches: "http://bkub.com")

        assert_search_equals([@bkub_url], url: "https://bkub.com")
      end
    end
  end
end
