# frozen_string_literal: true

require "test_helper"

module Sources
  class DeviantartTest < ActiveSupport::TestCase
    context "A modern source from deviantart" do
      alternate_should_work(
        "https://www.deviantart.com/yann-s/art/Nostalgia-for-infinity-GIF-animation-749119309",
        Sources::Alternates::Deviantart,
        "https://www.deviantart.com/yann-s/art/Nostalgia-for-infinity-GIF-animation-749119309",
      )
    end

    context "An old style source from deviantart" do
      alternate_should_work(
        "https://yann-s.deviantart.com/art/Nostalgia-for-infinity-GIF-animation-749119309",
        Sources::Alternates::Deviantart,
        "https://www.deviantart.com/yann-s/art/Nostalgia-for-infinity-GIF-animation-749119309",
      )
    end
  end
end
