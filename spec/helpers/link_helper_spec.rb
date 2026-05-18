# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkHelper do
  describe "#hostname_for_link" do
    subject(:hostname) { helper.hostname_for_link(path) }

    context "with an invalid URI" do
      let(:path) { "http://\x00bad" }

      it { is_expected.to be_nil }
    end

    context "with a relative path (no host)" do
      let(:path) { "/relative/path" }

      it { is_expected.to be_nil }
    end

    context "with an unknown domain" do
      let(:path) { "https://example.com/page" }

      it { is_expected.to be_nil }
    end

    context "with an unknown subdomain whose base is also unknown" do
      let(:path) { "https://sub.example.com/page" }

      it { is_expected.to be_nil }
    end

    context "with a direct domain match" do
      let(:path) { "https://twitter.com/user" }

      it { is_expected.to eq("twitter.com") }
    end

    context "with www prefix" do
      let(:path) { "https://www.twitter.com/user" }

      it "strips www and returns the domain" do
        expect(hostname).to eq("twitter.com")
      end
    end

    context "with an uppercase hostname" do
      let(:path) { "https://TWITTER.COM/user" }

      it "normalizes to lowercase" do
        expect(hostname).to eq("twitter.com")
      end
    end

    context "with an alias domain" do
      let(:path) { "https://x.com/user" }

      it "resolves the alias to the canonical domain" do
        expect(hostname).to eq("twitter.com")
      end
    end

    context "with www prefix on an alias domain" do
      let(:path) { "https://www.x.com/user" }

      it "strips www then resolves the alias" do
        expect(hostname).to eq("twitter.com")
      end
    end

    context "with a subdomain of a decoratable domain" do
      let(:path) { "https://sub.deviantart.com/art" }

      it "strips the subdomain and returns the base domain" do
        expect(hostname).to eq("deviantart.com")
      end
    end

    context "with a subdomain of an alias domain" do
      let(:path) { "https://profile.twimg.com/img" }

      it "strips the subdomain then resolves the alias" do
        expect(hostname).to eq("twitter.com")
      end
    end

    context "with a multi-segment domain that is itself in the list" do
      let(:path) { "https://img.booru.org/img" }

      it "matches the full multi-segment domain directly" do
        expect(hostname).to eq("img.booru.org")
      end
    end
  end

  describe "#favicon_for_link" do
    before do
      allow(helper).to receive(:vite_asset_path) { |p| "/assets/#{p}" }
      allow(helper).to receive(:svg_icon).and_return("".html_safe)
    end

    context "with a known URL" do
      subject(:img) { Nokogiri::HTML.fragment(helper.favicon_for_link("https://twitter.com/user")).at_css("img") }

      it "returns an img element" do
        expect(img).not_to be_nil
      end

      it "points to the correct favicon" do
        expect(img["src"]).to eq("/assets/images/favicons/twitter.com.png")
      end

      it "sets alt to the hostname" do
        expect(img["alt"]).to eq("twitter.com")
      end

      it "sets width and height to 16" do
        expect(img["width"]).to eq("16")
        expect(img["height"]).to eq("16")
      end

      it "sets the link-decoration class" do
        expect(img["class"]).to eq("link-decoration")
      end

      it "sets the data-hostname attribute" do
        expect(img["data-hostname"]).to eq("twitter.com")
      end
    end

    context "with an unknown URL" do
      it "delegates to svg_icon with the globe icon" do
        helper.favicon_for_link("https://example.com/page")
        expect(helper).to have_received(:svg_icon).with(:globe, class: "link-decoration", width: 16, height: 16)
      end

      it "returns the svg_icon result" do
        allow(helper).to receive(:svg_icon).and_return("<svg/>".html_safe)
        expect(helper.favicon_for_link("https://example.com/page")).to eq("<svg/>")
      end
    end
  end

  describe "#decorated_link_to" do
    subject(:link) { Nokogiri::HTML.fragment(helper.decorated_link_to("My Text", "https://twitter.com")).at_css("a") }

    let(:favicon_html) { "<img class=\"link-decoration\"/>".html_safe }

    before do
      allow(helper).to receive(:favicon_for_link).and_return(favicon_html)
    end

    it "renders an anchor element" do
      expect(link).not_to be_nil
    end

    it "sets href to the given path" do
      expect(link["href"]).to eq("https://twitter.com")
    end

    it "applies the decorated class" do
      expect(link["class"]).to eq("decorated")
    end

    it "includes the favicon inside the link" do
      expect(link.at_css("img.link-decoration")).not_to be_nil
    end

    it "includes the link text" do
      expect(link.text).to include("My Text")
    end
  end

  describe "favicon asset integrity" do
    it "has a favicon PNG for every decoratable domain" do
      favicon_dir = Rails.root.join("app/javascript/images/favicons")
      missing = LinkHelper::DECORATABLE_DOMAINS.reject do |domain|
        favicon_dir.join("#{domain}.png").exist?
      end
      expect(missing).to be_empty, "Missing favicon files: #{missing.join(', ')}"
    end
  end
end
