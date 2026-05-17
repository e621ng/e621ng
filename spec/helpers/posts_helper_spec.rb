# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostsHelper do
  describe "#try_parse_http_url" do
    subject(:hostname) { helper.try_parse_http_url(path)&.to_s }

    context "when the url starts with http://" do
      let(:path) { "http://example.com" }

      it { is_expected.to eq("http://example.com") }
    end

    context "when the url starts with https://" do
      let(:path) { "https://example.com" }

      it { is_expected.to eq("https://example.com") }
    end

    context "when the url starts with http:/" do
      let(:path) { "http:/example.com" }

      it "fixes the url by adding the missing slash" do
        expect(hostname).to eq("http://example.com")
      end
    end

    context "when the url starts with https:/" do
      let(:path) { "https:/example.com" }

      it "fixes the url by adding the missing slash" do
        expect(hostname).to eq("https://example.com")
      end
    end

    context "when the url starts with http:" do
      let(:path) { "http:example.com" }

      it "fixes the url by adding the missing slashes" do
        expect(hostname).to eq("http://example.com")
      end
    end

    context "when the url starts with https:" do
      let(:path) { "https:example.com" }

      it "fixes the url by adding the missing slashes" do
        expect(hostname).to eq("https://example.com")
      end
    end

    context "when the url is missing the protocol" do
      let(:path) { "example.com" }

      it "fixes the url by adding the http:// protocol" do
        expect(hostname).to eq("http://example.com")
      end
    end

    context "when the url starts with ftp://" do
      let(:path) { "ftp://example.com" }

      it { is_expected.to be_nil }
    end

    context "when the url starts with javascript:" do
      let(:path) { "javascript:example.com" }

      it { is_expected.to be_nil }
    end
  end

  describe "#post_source_tag" do
    before { CurrentUser.user = create(:user) }

    it "returns a span element with the source-invalid class for an invalid source" do
      html = Nokogiri::HTML.fragment(helper.post_source_tag("invalidSource")).at_css("span")
      expect(html.content).to eq("invalidSource")
      expect(html["class"]).to eq("source-invalid")
    end

    it "returns a strikethrough element for a source prefixed with -" do
      html = Nokogiri::HTML.fragment(helper.post_source_tag("-http://example.com")).at_css("s")
      expect(html.content).to eq("http://example.com")
    end

    it "returns a link element for a valid source for a user" do
      expect(Nokogiri::HTML.fragment(helper.post_source_tag("http://example.com")).at_css("a")["href"]).to eq("http://example.com")
    end

    it "returns a link element for a valid source with a second post search link for a janitor" do
      CurrentUser.user = create(:janitor_user)
      html = Nokogiri::HTML.fragment(helper.post_source_tag("http://example.com/image.png?query=test#example")).deconstruct
      expect(html[0]["href"]).to eq("http://example.com/image.png?query=test#example")
      expect(html[1].content).to eq(" ")
      expect(html[2]["href"]).to eq("/posts?tags=source%3Ahttp%3A%2F%2Fexample.com".html_safe)
    end
  end
end
