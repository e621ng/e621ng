# frozen_string_literal: true

require "test_helper"

module Sources
  class YoutubeTest < ActiveSupport::TestCase
    context "A regular YouTube watch URL" do
      alternate_should_work(
        "https://www.youtube.com/watch?v=HaBkohUTEg0",
        Sources::Alternates::Youtube,
        "https://www.youtube.com/watch?v=HaBkohUTEg0",
      )
    end

    context "A YouTube URL with query parameters" do
      alternate_should_work(
        "https://www.youtube.com/watch?v=-LbAAlpBfao&list=PLSVY1xk3gTEzjdlDxDH1rOtWnBkIiREzM&index=19",
        Sources::Alternates::Youtube,
        "https://www.youtube.com/watch?v=-LbAAlpBfao",
      )
    end

    context "A YouTube Shorts URL" do
      alternate_should_work(
        "https://www.youtube.com/shorts/ps4s9XNsDiY",
        Sources::Alternates::Youtube,
        "https://www.youtube.com/watch?v=ps4s9XNsDiY",
      )
    end

    context "A youtu.be short URL" do
      alternate_should_work(
        "https://youtu.be/uSRYoC3qFaE?si=PdP6a2dZWQJZAom_",
        Sources::Alternates::Youtube,
        "https://www.youtube.com/watch?v=uSRYoC3qFaE",
      )
    end
  end
end
