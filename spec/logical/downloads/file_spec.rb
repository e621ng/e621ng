# frozen_string_literal: true

require "rails_helper"

RSpec.describe Downloads::File do
  include_context "as member"

  before do
    allow(Resolv).to receive(:getaddress).and_return("1.2.3.4")
    allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([true, nil])
    allow(CloudflareService).to receive(:ips).and_return([])
  end

  def make_downloader(url = "https://example.com/image.jpg")
    described_class.new(url)
  end

  describe "#initialize" do
    it "accepts a valid HTTP URL" do
      expect { described_class.new("http://example.com/image.jpg") }.not_to raise_error
    end

    it "accepts a valid HTTPS URL" do
      expect { described_class.new("https://example.com/image.jpg") }.not_to raise_error
    end

    it "accepts an Addressable::URI directly" do
      uri = Addressable::URI.parse("https://example.com/image.jpg")
      expect { described_class.new(uri) }.not_to raise_error
    end

    it "normalizes the URL" do
      downloader = described_class.new("HTTPS://Example.COM/image.jpg")
      expect(downloader.url.to_s).to eq("https://example.com/image.jpg")
    end

    describe "blank URL" do
      it "raises ActiveModel::ValidationError for nil" do
        expect { described_class.new(nil) }
          .to raise_error(ActiveModel::ValidationError, /URL must not be blank/)
      end

      it "raises ActiveModel::ValidationError for empty string" do
        expect { described_class.new("") }
          .to raise_error(ActiveModel::ValidationError, /URL must not be blank/)
      end
    end

    describe "invalid scheme" do
      it "raises ActiveModel::ValidationError for ftp:// scheme with hint" do
        expect { described_class.new("ftp://example.com/file") }
          .to raise_error(ActiveModel::ValidationError, /Did you mean/)
      end
    end

    describe "blank host" do
      it "raises ActiveModel::ValidationError when host is missing" do
        expect { described_class.new("http:///path/to/file") }
          .to raise_error(ActiveModel::ValidationError, /not a valid url/)
      end
    end

    describe "IP address validation" do
      it "raises Downloads::File::Error for a private IP (10.x.x.x)" do
        allow(Resolv).to receive(:getaddress).and_return("10.0.0.1")
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end

      it "raises Downloads::File::Error for a loopback IP (127.0.0.1)" do
        allow(Resolv).to receive(:getaddress).and_return("127.0.0.1")
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end

      it "raises Downloads::File::Error for a link-local IP (169.254.x.x)" do
        allow(Resolv).to receive(:getaddress).and_return("169.254.1.1")
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end
    end

    describe "whitelist validation" do
      it "raises Downloads::File::Error when the URL is not whitelisted" do
        allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([false, "not in whitelist"])
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not whitelisted/)
      end
    end
  end

  describe "#strategy" do
    it "returns Sources::Strategies::Null for a non-Pixiv URL" do
      expect(make_downloader.strategy).to be_a(Sources::Strategies::Null)
    end

    it "returns Sources::Strategies::PixivSlim for a Pixiv URL" do
      expect(make_downloader("https://www.pixiv.net/artworks/12345678").strategy)
        .to be_a(Sources::Strategies::PixivSlim)
    end
  end

  describe "#file_url" do
    it "returns an Addressable::URI equal to the strategy image_url" do
      downloader = make_downloader("https://example.com/image.jpg")
      expect(downloader.file_url).to be_a(Addressable::URI)
      expect(downloader.file_url.to_s).to eq("https://example.com/image.jpg")
    end
  end

  describe "#is_cloudflare?" do
    let!(:downloader) { make_downloader }

    it "returns true when the resolved IP falls within a Cloudflare subnet" do
      allow(Resolv).to receive(:getaddress).and_return("104.16.0.1")
      allow(CloudflareService).to receive(:ips).and_return([IPAddr.new("104.16.0.0/12")])
      expect(downloader.is_cloudflare?(downloader.file_url)).to be true
    end

    it "returns false when the resolved IP is outside all Cloudflare subnets" do
      allow(Resolv).to receive(:getaddress).and_return("1.2.3.4")
      allow(CloudflareService).to receive(:ips).and_return([IPAddr.new("104.16.0.0/12")])
      expect(downloader.is_cloudflare?(downloader.file_url)).to be false
    end

    it "returns false when DNS resolution fails" do
      allow(Resolv).to receive(:getaddress).and_raise(Resolv::ResolvError)
      expect(downloader.is_cloudflare?(downloader.file_url)).to be false
    end
  end

  describe "#uncached_url" do
    let(:downloader) { make_downloader("https://example.com/image.jpg") }

    it "returns file_url unchanged when the host is not Cloudflare" do
      allow(downloader).to receive(:is_cloudflare?).and_return(false)
      expect(downloader.uncached_url).to eq(downloader.file_url)
    end

    it "adds a danbooru_no_cache query param for a Cloudflare host" do
      allow(downloader).to receive(:is_cloudflare?).and_return(true)
      expect(downloader.uncached_url.query_values).to have_key("danbooru_no_cache")
    end

    it "preserves existing query params when adding the cache-buster" do
      downloader = make_downloader("https://example.com/image.jpg?foo=bar")
      allow(downloader).to receive(:is_cloudflare?).and_return(true)
      params = downloader.uncached_url.query_values
      expect(params).to include("foo" => "bar")
      expect(params).to have_key("danbooru_no_cache")
    end
  end

  describe "#validate_uri_allowed!" do
    let(:downloader) { make_downloader }

    def call(url_string)
      downloader.send(:validate_uri_allowed!, Addressable::URI.parse(url_string))
    end

    it "returns nil immediately when hostname is blank" do
      expect(call("http:///path")).to be_nil
    end

    it "raises Downloads::File::Error for a private IP (10.x.x.x)" do
      allow(Resolv).to receive(:getaddress).and_return("10.0.0.1")
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises Downloads::File::Error for a loopback IP (127.0.0.1)" do
      allow(Resolv).to receive(:getaddress).and_return("127.0.0.1")
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises Downloads::File::Error for a link-local IP (169.254.x.x)" do
      allow(Resolv).to receive(:getaddress).and_return("169.254.1.1")
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises Downloads::File::Error when the URL is not whitelisted" do
      allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([false, "blocked"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not whitelisted/)
    end

    it "returns nil for a public IP with a whitelisted URL" do
      expect(call("https://example.com/image.jpg")).to be_nil
    end
  end

  describe "#download!" do
    let(:downloader) { make_downloader }
    let(:conn) { instance_double(Faraday::Connection) }
    let(:ok_response) { instance_double(Faraday::Response, success?: true, status: 200) }

    before do
      allow(Faraday).to receive(:new).and_return(conn)
      allow(conn).to receive(:get).and_return(ok_response)
    end

    it "returns a Tempfile on a successful response" do
      expect(downloader.download!).to be_a(Tempfile)
    end

    it "raises Downloads::File::Error on HTTP 404" do
      error_response = instance_double(Faraday::Response, success?: false, status: 404)
      allow(conn).to receive(:get).and_return(error_response)
      expect { downloader.download! }
        .to raise_error(Downloads::File::Error, /404 Not Found/)
    end

    it "raises Downloads::File::Error on HTTP 500" do
      error_response = instance_double(Faraday::Response, success?: false, status: 500)
      allow(conn).to receive(:get).and_return(error_response)
      expect { downloader.download! }
        .to raise_error(Downloads::File::Error, /500 Internal Server Error/)
    end

    it "raises Downloads::File::Error with 'too many redirects' on redirect limit" do
      allow(conn).to receive(:get)
        .and_raise(Faraday::FollowRedirects::RedirectLimitReached.new({ url: "https://example.com/" }))
      expect { downloader.download! }
        .to raise_error(Downloads::File::Error, /too many redirects/)
    end

    # FIXME: The on_data streaming callback (which enforces max_size) is never invoked
    # when Faraday::Connection#get is stubbed at the object level — the block configuring
    # req.options.on_data is not called, so the size check cannot be triggered this way.
    # Testing this path requires lower-level HTTP interception (e.g. WebMock with streaming
    # support) that is not currently set up in this project.
    # it "raises Downloads::File::Error when the file exceeds max_size" do
    #   expect { downloader.download!(max_size: 0) }
    #     .to raise_error(Downloads::File::Error, /too large/)
    # end
  end
end
