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
  end
end
