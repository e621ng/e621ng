# frozen_string_literal: true

require "test_helper"

module Sources
  class DerpibooruTest < ActiveSupport::TestCase
    context "A regular derpibooru.org image URL" do
      alternate_should_work(
        "https://derpibooru.org/images/3647155",
        Sources::Alternates::Derpibooru,
        "https://derpibooru.org/images/3647155",
      )
    end

    context "A derpibooru.org image URL with query parameters" do
      alternate_should_work(
        "https://derpibooru.org/images/3150017?q=my%3Awatched",
        Sources::Alternates::Derpibooru,
        "https://derpibooru.org/images/3150017",
      )
    end

    context "A derpicdn.net download URL with tags" do
      alternate_should_work(
        "https://derpicdn.net/img/download/2023/6/23/3150017__safe_artist-colon-cookieboy011_rumble_pegasus_pony_g4_angry_blatant+lies_blushing_colt_cute_foal_i27m+not+cute_madorable_male_rumblebetes_simple+backgr.png",
        Sources::Alternates::Derpibooru,
        "https://derpicdn.net/img/view/2023/6/23/3150017.png",
      )
    end

    context "A derpicdn.net view URL with tags" do
      alternate_should_work(
        "https://derpicdn.net/img/view/2025/7/24/3647155__safe_artist-colon-manbabbies_princess+cadance_princess+celestia_princess+luna_twilight+sparkle_alicorn_unicorn_anthro_plantigrade+anthro_g4_blood_brace.jpg",
        Sources::Alternates::Derpibooru,
        "https://derpicdn.net/img/view/2025/7/24/3647155.jpg",
      )
    end
  end
end
