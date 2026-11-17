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

    context "when the url only contains a protocol" do
      let(:path) { "http:" }

      it { is_expected.to be_nil }
    end

    context "when the url contains multiple protocols" do
      let(:path) { "http:http://example.com" }

      it { is_expected.to be_nil }
    end

    context "when it contains a malformed protocol" do
      let(:path) { "https:://example.com/" }

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

  describe "#nav_params_for" do
    it "keeps the search but drops API credentials" do
      helper.params.merge!(controller: "posts", action: "index", tags: "fox", login: "someone", api_key: "secret")
      expect(helper.send(:nav_params_for, 2)[:params].to_h).to eq("tags" => "fox", "page" => 2)
    end
  end

  describe "#flag_notice_open?" do
    include_context "as admin"

    # Members older than 3 days bypass the :REJ_NEWBIE throttle gate on post_flag creation.
    let(:flagger) { create(:user, created_at: 4.days.ago) }
    let(:uploader) { create(:user) }
    let(:post) { create(:post, uploader: uploader) }

    before { CurrentUser.scoped(flagger) { create(:post_flag, post: post) } }

    def open_for?(user)
      helper.flag_notice_open?(post.reload, user)
    end

    it "is open for staff" do
      expect(open_for?(create(:janitor_user))).to be true
    end

    it "is open for the flagger" do
      expect(open_for?(flagger)).to be true
    end

    it "is open for the uploader" do
      expect(open_for?(uploader)).to be true
    end

    it "is open for a user linked to one of the post's artists" do
      linked = create(:user)
      artist = create(:artist, linked_user_id: linked.id)
      post.update!(tag_string: "#{post.tag_string} #{artist.name}")
      expect(open_for?(linked)).to be true
    end

    it "is closed for an unrelated member" do
      expect(open_for?(create(:user))).to be false
    end

    it "is closed for anonymous users without looking up linked artists" do
      post.reload
      allow(post).to receive(:linked_users)
      expect(helper.flag_notice_open?(post, User.anonymous)).to be false
      expect(post).not_to have_received(:linked_users)
    end
  end
end
