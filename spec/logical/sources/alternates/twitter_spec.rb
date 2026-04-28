# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     Sources::Alternates::Twitter                            #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Twitter do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches twitter.com" do
      expect(described_class.new("https://twitter.com/user/status/123").match?).to be true
    end

    it "matches x.com" do
      expect(described_class.new("https://x.com/user/status/123").match?).to be true
    end

    it "matches pbs.twimg.com (subdomain of twimg.com)" do
      expect(described_class.new("https://pbs.twimg.com/media/GXabcd123.jpg").match?).to be true
    end

    it "matches fxtwitter.com" do
      expect(described_class.new("https://fxtwitter.com/user/status/123").match?).to be true
    end

    it "matches nitter.net" do
      expect(described_class.new("https://nitter.net/user/status/123").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// twitter.com URLs to https://" do
      expect(described_class.new("http://twitter.com/user/status/123").url).to start_with("https://")
    end

    it "upgrades http:// x.com URLs to https://" do
      expect(described_class.new("http://x.com/user/status/123").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — mobile URL normalization
  # -------------------------------------------------------------------------
  describe "#original_url — mobile URL normalization" do
    it "converts mobile.twitter.com to x.com" do
      expect(transform("https://mobile.twitter.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts mobile.x.com to x.com" do
      expect(transform("https://mobile.x.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — twitter.com → x.com
  # -------------------------------------------------------------------------
  describe "#original_url — twitter.com to x.com" do
    it "converts twitter.com status URL to x.com" do
      expect(transform("https://twitter.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts twitter.com profile URL to x.com" do
      expect(transform("https://twitter.com/someuser")).to eq("https://x.com/someuser")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — TwitFix mirrors → x.com
  # -------------------------------------------------------------------------
  describe "#original_url — TwitFix mirrors to x.com" do
    it "converts fxtwitter.com to x.com" do
      expect(transform("https://fxtwitter.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts fixupx.com to x.com" do
      expect(transform("https://fixupx.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts vxtwitter.com to x.com" do
      expect(transform("https://vxtwitter.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts twittpr.com to x.com" do
      expect(transform("https://twittpr.com/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — Nitter non-pic URLs → x.com
  # -------------------------------------------------------------------------
  describe "#original_url — Nitter status URLs to x.com" do
    it "converts nitter.net status URL to x.com" do
      expect(transform("https://nitter.net/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "converts nitter.poast.org status URL to x.com" do
      expect(transform("https://nitter.poast.org/user/status/123456789")).to eq("https://x.com/user/status/123456789")
    end

    it "passes through a non-nitter subdomain of a nitter domain unchanged" do
      # poast.org is in nitter_domains (as domain of nitter.poast.org),
      # but plain poast.org is not in NITTER_HOSTS, so original_url returns @url early.
      url = "https://poast.org/community/post/123"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — Nitter /pic/ proxy to pbs.twimg.com
  # -------------------------------------------------------------------------
  # FIXME: The nitter /pic/ transformation produces a malformed URL.
  # `@parsed_url.path[4..]` strips the leading `/pic` but leaves no leading `/`,
  # so Addressable serialises the result as `https://pbs.twimg.commedia/GXabcd123.jpg`
  # (host and path concatenated without a separator). The fix is to prepend "/" to
  # the decoded path before assigning it.
  #
  # describe "#original_url — Nitter /pic/ proxy to pbs.twimg.com" do
  #   it "converts nitter.net /pic/ URL to pbs.twimg.com direct URL" do
  #     expect(transform("https://nitter.net/pic/media%2FGXabcd123.jpg")).to \
  #       eq("https://pbs.twimg.com/media/GXabcd123.jpg")
  #   end
  # end

  # -------------------------------------------------------------------------
  # #original_url — x.com tracking parameter removal
  # -------------------------------------------------------------------------
  describe "#original_url — x.com tracking parameter removal" do
    it "removes the 's' tracking param" do
      expect(transform("https://x.com/user/status/123456789?s=20")).to eq("https://x.com/user/status/123456789")
    end

    it "removes the 't' tracking param" do
      expect(transform("https://x.com/user/status/123456789?t=AbCdEf")).to eq("https://x.com/user/status/123456789")
    end

    it "removes utm_source and other utm_* params" do
      expect(transform("https://x.com/user/status/123456789?utm_source=share&utm_medium=web")).to eq("https://x.com/user/status/123456789")
    end

    it "removes multiple tracking params simultaneously" do
      expect(transform("https://x.com/user/status/123456789?s=20&t=AbCdEf&utm_source=share")).to eq("https://x.com/user/status/123456789")
    end

    it "preserves non-tracking query params on x.com" do
      expect(transform("https://x.com/search?q=hello")).to eq("https://x.com/search?q=hello")
    end

    it "does not alter an x.com URL with no query string" do
      url = "https://x.com/user/status/123456789"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — /photo/N path suffix removal
  # -------------------------------------------------------------------------
  describe "#original_url — /photo/N path suffix removal" do
    it "removes /photo/1 from a status URL" do
      expect(transform("https://x.com/user/status/123456789/photo/1")).to eq("https://x.com/user/status/123456789")
    end

    it "removes /photo/2 from a status URL" do
      expect(transform("https://x.com/user/status/123456789/photo/2")).to eq("https://x.com/user/status/123456789")
    end

    it "does not strip /video/1 (only photo is removed)" do
      url = "https://x.com/user/status/123456789/video/1"
      expect(transform(url)).to eq(url)
    end

    it "does not alter a plain status URL with no trailing segment" do
      url = "https://x.com/user/status/123456789"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — pbs.twimg.com :orig format → ?name=orig&format=jpg
  # -------------------------------------------------------------------------
  describe "#original_url — pbs.twimg.com :format suffix normalization" do
    it "converts :orig suffix to ?format=jpg&name=orig" do
      expect(transform("https://pbs.twimg.com/media/GXabcd123.jpg:orig")).to eq("https://pbs.twimg.com/media/GXabcd123?format=jpg&name=orig")
    end

    it "converts :large suffix to ?format=jpg&name=large" do
      expect(transform("https://pbs.twimg.com/media/GXabcd123.jpg:large")).to eq("https://pbs.twimg.com/media/GXabcd123?format=jpg&name=large")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — pbs.twimg.com .ext format → ?format=ext
  # -------------------------------------------------------------------------
  describe "#original_url — pbs.twimg.com .ext format normalization" do
    it "converts .jpg extension to ?format=jpg" do
      expect(transform("https://pbs.twimg.com/media/GXabcd123.jpg")).to eq("https://pbs.twimg.com/media/GXabcd123?format=jpg")
    end

    it "converts .png extension to ?format=png" do
      expect(transform("https://pbs.twimg.com/media/GXabcd123.png")).to eq("https://pbs.twimg.com/media/GXabcd123?format=png")
    end

    it "does not alter already-normalised pbs.twimg.com URLs" do
      url = "https://pbs.twimg.com/media/GXabcd123?format=jpg&name=orig"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — combined transformations
  # -------------------------------------------------------------------------
  describe "#original_url — combined transformations" do
    it "converts twitter.com status with /photo/1 and tracking params to canonical x.com URL" do
      expect(transform("https://twitter.com/user/status/123456789/photo/1?s=20&t=abc")).to eq("https://x.com/user/status/123456789")
    end

    it "converts mobile.twitter.com with tracking params" do
      expect(transform("https://mobile.twitter.com/user/status/123456789?s=20")).to eq("https://x.com/user/status/123456789")
    end
  end
end
