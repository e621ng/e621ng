# frozen_string_literal: true

require "test_helper"

module Sources
  class InkbunnyTest < ActiveSupport::TestCase
    context "A normal source from Inkbunny" do
      alternate_should_work(
        "https://inkbunny.net/s/2082543",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/2082543",
      )
    end

    context "A direct image source from Inkbunny" do
      alternate_should_work(
        "https://gb2.ib.metapix.net/files/full/3012/3012936_MeganBryar_meganbryar.png",
        Sources::Alternates::Inkbunny,
        "https://gb2.ib.metapix.net/files/full/3012/3012936_MeganBryar_meganbryar.png",
      )
    end

    context "An Inkbunny source with an anchor" do
      alternate_should_work(
        "https://inkbunny.net/s/2582678-p2-#pictop",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/2582678-p2",
      )
    end

    context "An Inkbunny source with trailing dash" do
      alternate_should_work(
        "https://inkbunny.net/s/237847384-p3-",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/237847384-p3",
      )
    end

    context "A submissionview.php URL" do
      alternate_should_work(
        "https://inkbunny.net/submissionview.php?id=1382779",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/1382779",
      )
    end

    context "A submissionview.php URL with page number" do
      alternate_should_work(
        "https://inkbunny.net/submissionview.php?id=3123467&page=8",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/3123467-p8",
      )
    end

    context "A submissionview.php URL with page number 1" do
      alternate_should_work(
        "https://inkbunny.net/submissionview.php?id=3123467&page=1",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/3123467",
      )
    end

    context "A submissionview.php URL with an extra query part" do
      alternate_should_work(
        "https://inkbunny.net/submissionview.php?id=903232&latest",
        Sources::Alternates::Inkbunny,
        "https://inkbunny.net/s/903232",
      )
    end
  end
end
