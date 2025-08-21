# frozen_string_literal: true

require "test_helper"

module Sources
  class TwitterTest < ActiveSupport::TestCase
    context "A mobile x.com link" do
      alternate_should_work(
        "https://mobile.x.com/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A twitfix link" do
      alternate_should_work(
        "https://fxtwitter.com/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A nitter link" do
      alternate_should_work(
        "https://nitter.net/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A nitter link at an alternate host" do
      alternate_should_work(
        "https://nitter.poast.org/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A link to another service at a domain hosting a nitter instance" do
      alternate_should_work(
        "https://bibliogram.poast.org/u/britishwildlifecentre?track_me=True",
        Sources::Alternates::Twitter,
        "https://bibliogram.poast.org/u/britishwildlifecentre?track_me=True",
      )
    end

    context "A twitter.com to x.com conversion" do
      alternate_should_work(
        "https://twitter.com/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A mobile.twitter.com to x.com conversion" do
      alternate_should_work(
        "https://mobile.twitter.com/FalseKnees/status/1555698764622737408",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "An x.com link with tracking" do
      alternate_should_work(
        "https://x.com/Idolomantises/status/1554175127855673344?s=20&t=dow0UJIEEOousVoifzpLdg",
        Sources::Alternates::Twitter,
        "https://x.com/Idolomantises/status/1554175127855673344",
      )
    end

    context "A nitter link with tracking" do
      alternate_should_work(
        "https://nitter.space/Idolomantises/status/1554175127855673344?s=20&t=dow0UJIEEOousVoifzpLdg",
        Sources::Alternates::Twitter,
        "https://x.com/Idolomantises/status/1554175127855673344",
      )
    end

    context "A twitter.com profile link with tracking" do
      alternate_should_work(
        "https://twitter.com/Idolomantises?s=09",
        Sources::Alternates::Twitter,
        "https://x.com/Idolomantises",
      )
    end

    context "An old twitter direct image link" do
      alternate_should_work(
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE.jpg:orig",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE?format=jpg&name=orig",
      )
    end

    context "A twitter direct image link with name query param" do
      alternate_should_work(
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE.jpg?name=orig",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE?format=jpg&name=orig",
      )
    end

    context "A twitter direct image link with format query param" do
      alternate_should_work(
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE:orig?format=jpg",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE?format=jpg&name=orig",
      )
    end

    context "A modern twitter direct image link with all query parameters" do
      alternate_should_work(
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE?format=jpg&name=orig",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/E8v96meVgAkTKDE?format=jpg&name=orig",
      )
    end

    context "An old nitter direct link" do
      alternate_should_work(
        "https://nitter.net/pic/media%2FCTNngvZW4AAHvGM.jpg%3Asmall",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/CTNngvZW4AAHvGM?format=jpg&name=small",
      )
    end

    context "An nitter direct link with name specified" do
      alternate_should_work(
        "https://nitter.net/pic/media%2FCTNngvZW4AAHvGM.jpg%3Fname%3Dsmall",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/CTNngvZW4AAHvGM?format=jpg&name=small",
      )
    end

    context "A modern nitter direct link" do
      alternate_should_work(
        "https://nitter.net/pic/media%2FCTNngvZW4AAHvGM%3Fformat%3Djpg%26name%3Dsmall",
        Sources::Alternates::Twitter,
        "https://pbs.twimg.com/media/CTNngvZW4AAHvGM?format=jpg&name=small",
      )
    end

    context "An x.com photo link" do
      alternate_should_work(
        "https://x.com/FalseKnees/status/1555698764622737408/photo/1",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end

    context "A twitter.com photo link" do
      alternate_should_work(
        "https://twitter.com/FalseKnees/status/1555698764622737408/photo/1",
        Sources::Alternates::Twitter,
        "https://x.com/FalseKnees/status/1555698764622737408",
      )
    end
  end
end
