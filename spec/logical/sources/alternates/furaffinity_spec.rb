# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Furaffinity                          #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Furaffinity do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches furaffinity.net" do
      expect(described_class.new("https://www.furaffinity.net/view/12345678/").match?).to be true
    end

    it "matches facdn.net" do
      expect(described_class.new("https://d.facdn.net/art/user/1234567890/1234567890.user_image.jpg").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// furaffinity.net URLs to https://" do
      expect(described_class.new("http://www.furaffinity.net/view/12345678/").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — CDN domain normalization
  # -------------------------------------------------------------------------
  describe "#original_url — CDN domain normalization" do
    it "converts d.facdn.net to d.furaffinity.net" do
      expect(transform("https://d.facdn.net/art/user/1234567890/1234567890.user_image.jpg")).to \
        eq("https://d.furaffinity.net/art/user/1234567890/1234567890.user_image.jpg")
    end

    it "converts d2.facdn.net to d.furaffinity.net" do
      expect(transform("https://d2.facdn.net/art/user/1234567890/1234567890.user_image.jpg")).to \
        eq("https://d.furaffinity.net/art/user/1234567890/1234567890.user_image.jpg")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — SFW subdomain normalization
  # -------------------------------------------------------------------------
  describe "#original_url — SFW subdomain normalization" do
    it "converts sfw.furaffinity.net to furaffinity.net" do
      expect(transform("https://sfw.furaffinity.net/view/61758609")).to \
        eq("https://www.furaffinity.net/view/61758609")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — /full/ → /view/ path conversion
  # -------------------------------------------------------------------------
  describe "#original_url — /full/ to /view/ path conversion" do
    it "converts /full/12345678/ to /view/12345678/" do
      expect(transform("https://www.furaffinity.net/full/12345678/")).to eq("https://www.furaffinity.net/view/12345678/")
    end

    it "does not alter /view/ paths" do
      url = "https://www.furaffinity.net/view/12345678/"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — ?upload-successful query removal
  # -------------------------------------------------------------------------
  describe "#original_url — ?upload-successful query removal" do
    it "removes ?upload-successful from view URLs" do
      expect(transform("https://www.furaffinity.net/view/12345678/?upload-successful")).to eq("https://www.furaffinity.net/view/12345678/")
    end

    it "does not remove other query strings" do
      url = "https://www.furaffinity.net/view/12345678/?foo=bar"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — #cid: fragment removal
  # -------------------------------------------------------------------------
  describe "#original_url — #cid: fragment removal" do
    it "removes #cid:XXXXXXX fragment" do
      expect(transform("https://www.furaffinity.net/view/12345678/#cid:987654321")).to eq("https://www.furaffinity.net/view/12345678/")
    end

    it "preserves non-cid fragments" do
      url = "https://www.furaffinity.net/view/12345678/#gallery-section"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — combined transformations
  # -------------------------------------------------------------------------
  describe "#original_url — combined transformations" do
    it "converts d2.facdn.net /full/ URL with upload-successful query and cid fragment" do
      expect(transform("https://d2.facdn.net/full/12345678/?upload-successful#cid:111222333")).to \
        eq("https://d.furaffinity.net/view/12345678/")
    end
  end
end
