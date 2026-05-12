# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Sources::Alternates (module)                         #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates do
  # -------------------------------------------------------------------------
  # .all
  # -------------------------------------------------------------------------
  describe ".all" do
    it "includes all expected handler classes" do
      expect(described_class.all).to include(
        Sources::Alternates::Furaffinity,
        Sources::Alternates::Pixiv,
        Sources::Alternates::Deviantart,
        Sources::Alternates::Twitter,
        Sources::Alternates::Inkbunny,
        Sources::Alternates::Youtube,
        Sources::Alternates::Derpibooru,
        Sources::Alternates::Facebook,
        Sources::Alternates::Webtoons,
        Sources::Alternates::Tapas,
        Sources::Alternates::Imgur,
      )
    end

    it "does not include Null in the handler list" do
      expect(described_class.all).not_to include(Sources::Alternates::Null)
    end
  end

  # -------------------------------------------------------------------------
  # .find
  # -------------------------------------------------------------------------
  describe ".find" do
    it "returns a Twitter instance for an x.com URL" do
      expect(described_class.find("https://x.com/user/status/123")).to be_a(Sources::Alternates::Twitter)
    end

    it "returns a Pixiv instance for a pixiv.net URL" do
      expect(described_class.find("https://www.pixiv.net/artworks/80169645")).to be_a(Sources::Alternates::Pixiv)
    end

    it "returns a Deviantart instance for a deviantart.com URL" do
      expect(described_class.find("https://www.deviantart.com/artist/art/title-12345")).to be_a(Sources::Alternates::Deviantart)
    end

    it "returns a Furaffinity instance for a furaffinity.net URL" do
      expect(described_class.find("https://www.furaffinity.net/view/12345678/")).to be_a(Sources::Alternates::Furaffinity)
    end

    it "returns an Inkbunny instance for an inkbunny.net URL" do
      expect(described_class.find("https://inkbunny.net/s/1234567")).to be_a(Sources::Alternates::Inkbunny)
    end

    it "returns a Youtube instance for a youtube.com URL" do
      expect(described_class.find("https://www.youtube.com/watch?v=dQw4w9WgXcQ")).to be_a(Sources::Alternates::Youtube)
    end

    it "returns a Derpibooru instance for a derpibooru.org URL" do
      expect(described_class.find("https://derpibooru.org/images/12345")).to be_a(Sources::Alternates::Derpibooru)
    end

    it "returns a Facebook instance for a facebook.com URL" do
      expect(described_class.find("https://www.facebook.com/photo.php?fbid=123456789")).to be_a(Sources::Alternates::Facebook)
    end

    it "returns a Webtoons instance for a webtoons.com URL" do
      expect(described_class.find("https://www.webtoons.com/en/canvas/forestdale/viewer?title_no=856922&episode_no=314")).to be_a(Sources::Alternates::Webtoons)
    end

    it "returns a Tapas instance for a tapas.io URL" do
      expect(described_class.find("https://tapas.io/episode/189498")).to be_a(Sources::Alternates::Tapas)
    end

    it "returns an Imgur instance for an imgur.com URL" do
      expect(described_class.find("https://imgur.com/a/zZkdMts")).to be_a(Sources::Alternates::Imgur)
    end

    it "returns a Null instance for an unrecognised URL by default" do
      expect(described_class.find("https://example.com/image.jpg")).to be_a(Sources::Alternates::Null)
    end

    it "returns nil for an unrecognised URL when default: nil" do
      expect(described_class.find("https://example.com/image.jpg", default: nil)).to be_nil
    end

    it "returns a Null instance for a nil URL by default" do
      expect(described_class.find(nil)).to be_a(Sources::Alternates::Null)
    end

    it "returns nil for a nil URL when default: nil" do
      expect(described_class.find(nil, default: nil)).to be_nil
    end
  end
end
