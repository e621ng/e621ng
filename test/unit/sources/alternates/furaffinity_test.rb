# frozen_string_literal: true

require "test_helper"

module Sources
  class FuraffinityTest < ActiveSupport::TestCase
    context "A modern source from Furaffinity" do
      alternate_should_work(
        "https://www.furaffinity.net/view/27836238/",
        Sources::Alternates::Furaffinity,
        "https://www.furaffinity.net/view/27836238/",
      )
    end

    context "An old CDN direct link from Furaffinity" do
      alternate_should_work(
        "https://d.facdn.net/art/zephyr42/1530401739/1530401739.zephyr42_zephyrfullscene_fullsize_preview.png",
        Sources::Alternates::Furaffinity,
        "https://d.furaffinity.net/art/zephyr42/1530401739/1530401739.zephyr42_zephyrfullscene_fullsize_preview.png",
      )
    end

    context "A broken CDN direct link from Furaffinity" do
      alternate_should_work(
        "https://d2.facdn.net/art/zephyr42/1530401739/1530401739.zephyr42_zephyrfullscene_fullsize_preview.png",
        Sources::Alternates::Furaffinity,
        "https://d.furaffinity.net/art/zephyr42/1530401739/1530401739.zephyr42_zephyrfullscene_fullsize_preview.png",
      )
    end

    context "An FA submission link using /full/" do
      alternate_should_work(
        "https://www.furaffinity.net/full/27836238/",
        Sources::Alternates::Furaffinity,
        "https://www.furaffinity.net/view/27836238/",
      )
    end

    context "An FA submission link with an upload-successful query" do
      alternate_should_work(
        "https://www.furaffinity.net/view/27836238/?upload-successful",
        Sources::Alternates::Furaffinity,
        "https://www.furaffinity.net/view/27836238/",
      )
    end

    context "An FA submission link with a comment anchor" do
      alternate_should_work(
        "https://www.furaffinity.net/view/27836238/#cid:130552607",
        Sources::Alternates::Furaffinity,
        "https://www.furaffinity.net/view/27836238/",
      )
    end
  end
end
