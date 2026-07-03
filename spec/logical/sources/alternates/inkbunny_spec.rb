# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Inkbunny                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Inkbunny do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches inkbunny.net" do
      expect(described_class.new("https://inkbunny.net/s/1234567").match?).to be true
    end

    it "matches metapix.net" do
      expect(described_class.new("https://metapix.net/s/1234567").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// inkbunny.net URLs to https://" do
      expect(described_class.new("http://inkbunny.net/s/1234567").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — fragment anchor removal
  # -------------------------------------------------------------------------
  describe "#original_url — fragment anchor removal" do
    it "removes fragment anchor from submission URLs" do
      expect(transform("https://inkbunny.net/s/1234567#comment-9876543")).to eq("https://inkbunny.net/s/1234567")
    end

    it "removes fragment anchor from gallery URLs" do
      expect(transform("https://inkbunny.net/user#submissions")).to eq("https://inkbunny.net/user")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — trailing dash removal
  # -------------------------------------------------------------------------
  describe "#original_url — trailing dash removal" do
    it "removes a trailing dash from the path" do
      expect(transform("https://inkbunny.net/s/1234567-")).to eq("https://inkbunny.net/s/1234567")
    end

    it "does not alter paths without a trailing dash" do
      url = "https://inkbunny.net/s/1234567"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — submissionview.php canonicalization
  # -------------------------------------------------------------------------
  describe "#original_url — submissionview.php canonicalization" do
    it "converts /submissionview.php?id=X to /s/X" do
      expect(transform("https://inkbunny.net/submissionview.php?id=1234567")).to eq("https://inkbunny.net/s/1234567")
    end

    it "converts /submissionview.php?id=X&page=1 to /s/X (page 1 not appended)" do
      expect(transform("https://inkbunny.net/submissionview.php?id=1234567&page=1")).to eq("https://inkbunny.net/s/1234567")
    end

    it "converts /submissionview.php?id=X&page=2 to /s/X-p2" do
      expect(transform("https://inkbunny.net/submissionview.php?id=1234567&page=2")).to eq("https://inkbunny.net/s/1234567-p2")
    end

    it "converts /submissionview.php?id=X&page=5 to /s/X-p5" do
      expect(transform("https://inkbunny.net/submissionview.php?id=1234567&page=5")).to eq("https://inkbunny.net/s/1234567-p5")
    end

    it "does not convert metapix.net submissionview.php URLs (host guard is inkbunny.net only)" do
      url = "https://metapix.net/submissionview.php?id=1234567"
      expect(transform(url)).to eq(url)
    end

    it "passes through already-canonical /s/X URLs unchanged" do
      url = "https://inkbunny.net/s/1234567"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — combined transformations
  # -------------------------------------------------------------------------
  describe "#original_url — combined transformations" do
    it "removes fragment then converts submissionview.php to /s/ URL" do
      expect(transform("https://inkbunny.net/submissionview.php?id=1234567#page-top")).to eq("https://inkbunny.net/s/1234567")
    end

    it "removes fragment and trailing dash from short URL" do
      expect(transform("https://inkbunny.net/s/1234567-#comment-99")).to eq("https://inkbunny.net/s/1234567")
    end
  end
end
