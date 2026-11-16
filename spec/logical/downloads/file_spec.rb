# frozen_string_literal: true

require "rails_helper"
require "webmock"

RSpec.describe Downloads::File do
  include_context "as member"

  before do
    # #validate_uri_allowed! / #pin_connection! resolve via Resolv.getaddresses (plural);
    # #is_cloudflare? still uses Resolv.getaddress (singular).
    allow(Resolv).to receive_messages(getaddresses: ["1.2.3.4"], getaddress: "1.2.3.4")
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
      it "raises Downloads::File::Error for nil" do
        expect { described_class.new(nil) }
          .to raise_error(Downloads::File::Error, /URL must not be blank/)
      end

      it "raises Downloads::File::Error for empty string" do
        expect { described_class.new("") }
          .to raise_error(Downloads::File::Error, /URL must not be blank/)
      end
    end

    describe "invalid scheme" do
      it "raises Downloads::File::Error for ftp:// scheme without the http hint" do
        expect { described_class.new("ftp://example.com/file") }.to raise_error(Downloads::File::Error) do |e|
          expect(e.message).to include("Only http and https are supported")
          expect(e.message).not_to include("Did you mean")
        end
      end

      it "raises Downloads::File::Error with the http hint when the scheme is absent" do
        expect { described_class.new("example.com/file.jpg") }
          .to raise_error(Downloads::File::Error, %r{Did you mean 'http://})
      end
    end

    describe "blank host" do
      it "raises Downloads::File::Error when host is missing" do
        expect { described_class.new("http:///path/to/file") }
          .to raise_error(Downloads::File::Error, /not a valid URL/)
      end
    end

    describe "IP address validation" do
      it "raises Downloads::File::Error for a private IP (10.x.x.x)" do
        allow(Resolv).to receive(:getaddresses).and_return(["10.0.0.1"])
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end

      it "raises Downloads::File::Error for a loopback IP (127.0.0.1)" do
        allow(Resolv).to receive(:getaddresses).and_return(["127.0.0.1"])
        expect { described_class.new("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end

      it "raises Downloads::File::Error for a link-local IP (169.254.x.x)" do
        allow(Resolv).to receive(:getaddresses).and_return(["169.254.1.1"])
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

    it "returns Sources::Strategies::InkbunnySlim for an Inkbunny image URL" do
      expect(make_downloader("https://us.ib.metapix.net/files/screen/5604/5604180_ColdBloodedTwilight_2025_474.png").strategy)
        .to be_a(Sources::Strategies::InkbunnySlim)
    end

    it "sends the Inkbunny referer for metapix.net downloads" do
      strategy = make_downloader("https://us.ib.metapix.net/files/full/5604/5604180_ColdBloodedTwilight_2025.png").strategy
      expect(strategy.headers).to eq(referer: "https://inkbunny.net")
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
      allow(Resolv).to receive(:getaddresses).and_return(["10.0.0.1"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises Downloads::File::Error for a loopback IP (127.0.0.1)" do
      allow(Resolv).to receive(:getaddresses).and_return(["127.0.0.1"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises Downloads::File::Error for a link-local IP (169.254.x.x)" do
      allow(Resolv).to receive(:getaddresses).and_return(["169.254.1.1"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises when ANY resolved record is blocked, even if the first is public" do
      # Multi-record bypass: getaddress would only inspect the first (public) record.
      allow(Resolv).to receive(:getaddresses).and_return(["1.2.3.4", "10.0.0.1"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "raises when the host resolves to no addresses (fail closed)" do
      allow(Resolv).to receive(:getaddresses).and_return([])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /could not resolve/i)
    end

    it "raises when resolution fails (fail closed)" do
      allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /could not resolve/i)
    end

    it "raises a clean error (not a 500) when a resolved record is unparseable by IPAddr" do
      allow(Resolv).to receive(:getaddresses).and_return(["not-an-ip-address"])
      expect { call("https://example.com/image.jpg") }
        .to raise_error(Downloads::File::Error, /could not resolve/i)
    end

    it "validates an IP-literal host directly without DNS resolution" do
      expect { call("https://127.0.0.1/image.jpg") }
        .to raise_error(Downloads::File::Error, /not allowed/)
      expect(Resolv).not_to have_received(:getaddresses).with("127.0.0.1")
    end

    # IPv6 transition and IPv4-mapped addresses embed a blocked IPv4 target but are
    # invisible to IPAddr#private?/#loopback?/#link_local? (SSRF guard bypass).
    {
      "NAT64 loopback (64:ff9b::7f00:1)" => "64:ff9b::7f00:1",
      "NAT64 cloud metadata (64:ff9b::a9fe:a9fe)" => "64:ff9b::a9fe:a9fe",
      "6to4 loopback (2002:7f00:0001::)" => "2002:7f00:0001::",
      "6to4 cloud metadata (2002:a9fe:a9fe::)" => "2002:a9fe:a9fe::",
      "IPv4-mapped loopback (::ffff:127.0.0.1)" => "::ffff:127.0.0.1",
      "IPv4-compatible loopback (::7f00:1)" => "::7f00:1",
      "unspecified address (0.0.0.0)" => "0.0.0.0",
      "unspecified IPv6 address (::)" => "::",
      # Reserved / special-purpose ranges outside the RFC 1918 and link-local blocks
      "IETF protocol assignments (192.0.0.192)" => "192.0.0.192",
      "benchmarking (198.18.0.1)" => "198.18.0.1",
      "IPv4 multicast (224.0.0.1)" => "224.0.0.1",
      "reserved (240.0.0.1)" => "240.0.0.1",
      "limited broadcast (255.255.255.255)" => "255.255.255.255",
      "IPv6 site-local (fec0::1)" => "fec0::1",
      "IPv6 multicast (ff02::1)" => "ff02::1",
    }.each do |description, address|
      it "raises Downloads::File::Error for #{description}" do
        allow(Resolv).to receive(:getaddresses).and_return([address])
        expect { call("https://example.com/image.jpg") }
          .to raise_error(Downloads::File::Error, /not allowed/)
      end
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

  describe "#pin_connection!" do
    let(:downloader) { make_downloader }

    def pin(host, port = 443)
      http = Net::HTTP.new(host, port)
      downloader.send(:pin_connection!, http)
      http
    end

    it "pins the connection to the validated IP while preserving the hostname" do
      allow(Resolv).to receive(:getaddresses).and_return(["1.2.3.4"])
      http = pin("example.com")
      expect(http.ipaddr).to eq("1.2.3.4")
      expect(http.address).to eq("example.com") # Host header / TLS SNI unchanged
    end

    it "refuses to pin when the host rebinds to a blocked address" do
      allow(Resolv).to receive(:getaddresses).and_return(["1.2.3.4", "10.0.0.1"])
      expect { pin("example.com") }.to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "prefers an IPv4 record when both families resolve (keeps v6-only pins from breaking downloads)" do
      allow(Resolv).to receive(:getaddresses).and_return(["2606:4700::1111", "1.2.3.4"])
      expect(pin("example.com").ipaddr).to eq("1.2.3.4")
    end

    it "pins a resolved IPv6 address in unbracketed form" do
      allow(Resolv).to receive(:getaddresses).and_return(["2606:4700::1111"])
      http = pin("example.com")
      expect(http.ipaddr).to eq("2606:4700::1111")
    end

    it "refuses a blocked IPv6 literal host" do
      expect { pin("[::1]") }.to raise_error(Downloads::File::Error, /not allowed/)
    end

    it "re-validates on every call (covers redirects and retries)" do
      allow(Resolv).to receive(:getaddresses).and_return(["1.2.3.4"])
      expect { pin("example.com") }.not_to raise_error

      allow(Resolv).to receive(:getaddresses).and_return(["169.254.169.254"])
      expect { pin("example.com") }.to raise_error(Downloads::File::Error, /not allowed/)
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

    it "raises Downloads::File::Error when the connection fails" do
      allow(conn).to receive(:get).and_raise(Faraday::ConnectionFailed, "boom")
      expect { downloader.download! }
        .to raise_error(Downloads::File::Error, /Couldn't download the file/)
    end

    it "raises Downloads::File::Error when the request times out" do
      allow(conn).to receive(:get).and_raise(Faraday::TimeoutError)
      expect { downloader.download! }
        .to raise_error(Downloads::File::Error, /Couldn't download the file/)
    end
  end

  # Runs the real Faraday stack so the on_data callback is exercised. WebMock is
  # enabled only around these examples to keep it out of the rest of the suite.
  describe "#download! over HTTP" do
    include WebMock::API

    let(:url) { "https://example.com/image.jpg" }

    around do |example|
      WebMock.enable!
      example.run
    ensure
      WebMock.reset!
      WebMock.disable!
    end

    it "returns the response body" do
      stub_request(:get, url).to_return(status: 200, body: "IMAGE")
      expect(make_downloader(url).download!.read).to eq("IMAGE")
    end

    [301, 302, 303, 307, 308].each do |status|
      it "does not write the body of a #{status} redirect into the file" do
        stub_request(:get, url).to_return(status: status, headers: { "Location" => "https://example.com/real.jpg" }, body: "<html>Moved</html>")
        stub_request(:get, "https://example.com/real.jpg").to_return(status: 200, body: "IMAGE")
        expect(make_downloader(url).download!.read).to eq("IMAGE")
      end
    end

    context "with upload URL rules" do
      let(:blocked) { "https://example.com/sample/real.jpg" }

      before do
        create(:blocking_upload_url_rule, label: "Sample URL")
        stub_request(:get, url).to_return(status: 302, headers: { "Location" => blocked })
        stub_request(:get, blocked).to_return(status: 200, body: "IMAGE")
      end

      it "follows a redirect to a blocked URL when rules are not enforced" do
        expect(make_downloader(url).download!.read).to eq("IMAGE")
      end

      it "refuses a redirect to a blocked URL when rules are enforced" do
        expect { described_class.new(url, enforce_rules: true).download! }
          .to raise_error(Downloads::File::RuleError, /is not allowed: Sample URL/)
      end

      it "refuses a blocked URL at construction when rules are enforced" do
        expect { described_class.new(blocked, enforce_rules: true) }.to raise_error(Downloads::File::RuleError)
        expect { described_class.new(blocked) }.not_to raise_error
      end

      it "refuses when a rule fails to evaluate" do
        allow(UploadUrlRule).to receive(:evaluate).and_raise(UploadUrlRule::EvaluationError.new("Slow"))
        expect { described_class.new(url, enforce_rules: true) }
          .to raise_error(Downloads::File::RuleError, /could not be checked/)
      end

      it "refuses an overlong URL that the rules cannot check" do
        expect { described_class.new("#{blocked}?pad=#{'a' * 2_000}", enforce_rules: true) }
          .to raise_error(Downloads::File::RuleError, /longer than 2000 characters/)
      end

      it "ignores recommend rules" do
        UploadUrlRule.update_all(handling: "recommend")
        UploadUrlRule.clear_cache
        expect(described_class.new(url, enforce_rules: true).download!.read).to eq("IMAGE")
      end
    end

    it "raises Downloads::File::Error when the file exceeds max_size" do
      stub_request(:get, url).to_return(status: 200, body: "IMAGE")
      expect { make_downloader(url).download!(max_size: 4) }
        .to raise_error(Downloads::File::Error, /too large/)
    end

    it "raises Downloads::File::Error when the transfer outlasts the deadline" do
      stub_request(:get, url).to_return(status: 200, body: "IMAGE")
      expect { make_downloader(url).download!(deadline: -1) }
        .to raise_error(Downloads::File::Error, /took too long/)
    end

    it "returns the body when the transfer finishes within the deadline" do
      stub_request(:get, url).to_return(status: 200, body: "IMAGE")
      expect(make_downloader(url).download!(deadline: 60).read).to eq("IMAGE")
    end

    it "stops following redirects once the deadline passes" do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "https://example.com/real.jpg" }, body: "<html>Moved</html>")
      stub_request(:get, "https://example.com/real.jpg").to_return(status: 200, body: "IMAGE")
      downloader = make_downloader(url)
      # Start, first hop's timeouts, then the redirect body arrives past the deadline.
      allow(downloader).to receive(:monotonic_now).and_return(0, 0, 100)
      expect { downloader.download!(deadline: 20) }.to raise_error(Downloads::File::Error, /took too long/)
      expect(WebMock::RequestRegistry.instance.times_executed(a_request(:get, "https://example.com/real.jpg"))).to eq(0)
    end

    describe "temporary file cleanup" do
      let(:tempfiles) { [] }

      before do
        allow(Tempfile).to receive(:new).and_wrap_original do |original, *args, **kwargs|
          original.call(*args, **kwargs).tap { |file| tempfiles << file }
        end
      end

      it "closes the file when the size limit is exceeded" do
        stub_request(:get, url).to_return(status: 200, body: "IMAGE")
        expect { make_downloader(url).download!(max_size: 4) }.to raise_error(Downloads::File::Error)
        expect(tempfiles).to all(be_closed)
      end

      it "closes the file when the deadline passes" do
        stub_request(:get, url).to_return(status: 200, body: "IMAGE")
        expect { make_downloader(url).download!(deadline: -1) }.to raise_error(Downloads::File::Error)
        expect(tempfiles).to all(be_closed)
      end

      it "closes the file on an HTTP error status" do
        stub_request(:get, url).to_return(status: 404)
        expect { make_downloader(url).download! }.to raise_error(Downloads::File::Error, /404/)
        expect(tempfiles).to all(be_closed)
      end
    end
  end

  describe "#limit_timeouts!" do
    let(:http) { Net::HTTP.new("example.com").tap { |h| h.open_timeout = h.read_timeout = 10 } }
    let(:downloader) { make_downloader }

    before { allow(downloader).to receive(:monotonic_now).and_return(100) }

    it "shrinks the open and read timeouts to the time left" do
      downloader.limit_timeouts!(http, 103)
      expect(http.open_timeout).to eq(3)
      expect(http.read_timeout).to eq(3)
    end

    it "keeps shorter timeouts" do
      downloader.limit_timeouts!(http, 150)
      expect(http.open_timeout).to eq(10)
      expect(http.read_timeout).to eq(10)
    end

    it "raises once the deadline has passed" do
      expect { downloader.limit_timeouts!(http, 100) }.to raise_error(Downloads::File::Error, /took too long/)
    end
  end
end
