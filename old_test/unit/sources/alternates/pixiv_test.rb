# frozen_string_literal: true

require "test_helper"

module Sources
  class PixivTest < ActiveSupport::TestCase
    context "A member_illust.php URL" do
      alternate_should_work(
        "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/18557054",
      )
    end

    context "A member_illust.php URL with mode=big" do
      alternate_should_work(
        "http://www.pixiv.net/member_illust.php?mode=big&illust_id=18557054",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/18557054",
      )
    end

    context "A member_illust.php URL with mode=manga" do
      alternate_should_work(
        "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/18557054",
      )
    end

    context "A member_illust.php URL with mode=manga_big and page" do
      alternate_should_work(
        "http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054&page=1",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/18557054",
      )
    end

    context "A short /i/ URL" do
      alternate_should_work(
        "http://www.pixiv.net/i/18557054",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/18557054",
      )
    end

    context "An /en/artworks/ URL" do
      alternate_should_work(
        "https://www.pixiv.net/en/artworks/80169645",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/80169645",
      )
    end

    context "An /artworks/ URL" do
      alternate_should_work(
        "https://www.pixiv.net/artworks/80169645",
        Sources::Alternates::Pixiv,
        "https://www.pixiv.net/artworks/80169645",
      )
    end

    context "An old pixiv image URL" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("http://img18.pixiv.net/img/evazion/14901720.png")
        @pixiv.parse
      end

      should "preserve original URL" do
        assert_equal "https://img18.pixiv.net/img/evazion/14901720.png", @pixiv.original_url
      end

      should "add submission URL" do
        assert_equal "https://www.pixiv.net/artworks/14901720", @pixiv.submission_url
      end
    end

    context "A new pximg.net image URL" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("https://i.pximg.net/img-original/img/2014/10/03/18/10/20/46324488_p0.png")
        @pixiv.parse
      end

      should "preserve original URL" do
        assert_equal "https://i.pximg.net/img-original/img/2014/10/03/18/10/20/46324488_p0.png", @pixiv.original_url
      end

      should "add submission URL" do
        assert_equal "https://www.pixiv.net/artworks/46324488", @pixiv.submission_url
      end
    end

    context "A new pximg.net master image URL" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("https://i.pximg.net/img-master/img/2014/10/03/18/10/20/46324488_p0_master1200.jpg")
        @pixiv.parse
      end

      should "preserve original URL" do
        assert_equal "https://i.pximg.net/img-master/img/2014/10/03/18/10/20/46324488_p0_master1200.jpg", @pixiv.original_url
      end

      should "add submission URL" do
        assert_equal "https://www.pixiv.net/artworks/46324488", @pixiv.submission_url
      end
    end

    context "An old pixiv image URL with subdirectory" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("http://i2.pixiv.net/img18/img/evazion/14901720.png")
        @pixiv.parse
      end

      should "preserve original URL and add submission URL" do
        assert_equal "https://i2.pixiv.net/img18/img/evazion/14901720.png", @pixiv.original_url
        assert_equal "https://www.pixiv.net/artworks/14901720", @pixiv.submission_url
      end
    end

    context "An old pixiv image URL with _m suffix" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("http://i2.pixiv.net/img18/img/evazion/14901720_m.png")
        @pixiv.parse
      end

      should "preserve original URL and add submission URL" do
        assert_equal "https://i2.pixiv.net/img18/img/evazion/14901720_m.png", @pixiv.original_url
        assert_equal "https://www.pixiv.net/artworks/14901720", @pixiv.submission_url
      end
    end

    context "An ugoira zip URL" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("http://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip")
        @pixiv.parse
      end

      should "preserve original URL and add submission URL" do
        assert_equal "https://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip", @pixiv.original_url
        assert_equal "https://www.pixiv.net/artworks/46323924", @pixiv.submission_url
      end
    end

    context "A novel cover image" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("https://i.pximg.net/novel-cover-original/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42.jpg")
        @pixiv.parse
      end

      should "return original URL unchanged" do
        assert_equal "https://i.pximg.net/novel-cover-original/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42.jpg", @pixiv.original_url
      end

      should "not add submission URL" do
        assert_nil @pixiv.submission_url
      end
    end

    context "An img-sketch URL" do
      setup do
        @pixiv = Sources::Alternates::Pixiv.new("https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg")
        @pixiv.parse
      end

      should "return original URL unchanged" do
        assert_equal "https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg", @pixiv.original_url
      end

      should "not add submission URL" do
        assert_nil @pixiv.submission_url
      end
    end
  end
end
