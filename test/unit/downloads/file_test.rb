require 'test_helper'

module Downloads
  class FileTest < ActiveSupport::TestCase
    def assert_correct_escaping(input, output)
      file = Downloads::File.new(input)
      assert_equal(file.url.to_s, output)

      # Validate that no double-encoding is going on
      file = Downloads::File.new(file.url.to_s)
      assert_equal(file.url.to_s, output)
    end

    context "A post download" do
      setup do
        CurrentUser.user = create(:user)
        CloudflareService.stubs(:ips).returns([])
        UploadWhitelist.stubs(:is_whitelisted?).returns(true)
        @source = "http://www.google.com/intl/en_ALL/images/logo.gif"
        @download = Downloads::File.new(@source)
        stub_request(:get, @source).to_return(status: 200, body: file_fixture("test.jpg").read, headers: {})
      end

      context "for a banned IP" do
        setup do
          Resolv.expects(:getaddress).returns("127.0.0.1").at_least_once
        end

        should "not try to download the file" do
          assert_raise(Downloads::File::Error) { Downloads::File.new("http://evil.com").download! }
        end

        should "not try to fetch the size" do
          assert_raise(Downloads::File::Error) { Downloads::File.new("http://evil.com").size }
        end

        should "not follow redirects to banned IPs" do
          url = "http://httpbin.org/redirect-to?url=http://127.0.0.1"
          stub_request(:get, url).to_return(status: 301, headers: { "Location": "http://127.0.0.1" })

          assert_raise(Downloads::File::Error) { Downloads::File.new(url).download! }
        end

        should "not follow redirects that resolve to a banned IP" do
          url = "http://httpbin.org/redirect-to?url=http://127.0.0.1.nip.io"
          stub_request(:get, url).to_return(status: 301, headers: { "Location": "http://127.0.0.1.xip.io" })

          assert_raise(Downloads::File::Error) { Downloads::File.new(url).download! }
        end
      end

      context "that fails" do
        should "retry three times before giving up" do
          HTTParty.expects(:get).times(3).raises(Errno::ETIMEDOUT)
          assert_raises(Errno::ETIMEDOUT) { @download.download! }
        end

        should "return an uncorrupted file on the second try" do
          bomb = stub("bomb")
          bomb.expects(:size).raises(IOError)
          resp = stub("resp", success?: true)

          HTTParty.expects(:get).twice.multiple_yields("a", bomb, "b", "c").then.multiple_yields("a", "b", "c").returns(resp)
          @download.stubs(:is_cloudflare?).returns(false)
          tempfile = @download.download!

          assert_equal("abc", tempfile.read)
        end
      end

      should "throw an exception when the file is larger than the maximum" do
        assert_raise(Downloads::File::Error) do
          @download.download!(max_size: 1)
        end
      end

      should "store the file in the tempfile path" do
        tempfile = @download.download!
        assert_operator(tempfile.size, :>, 0, "should have data")
      end

      context "url normalization" do
        should "correctly escapes cyrilic characters" do
          input = "https://d.furaffinity.net/art/peyzazhik/1629082282/1629082282.peyzazhik_заливать-гитару.jpg"
          output = "https://d.furaffinity.net/art/peyzazhik/1629082282/1629082282.peyzazhik_%D0%B7%D0%B0%D0%BB%D0%B8%D0%B2%D0%B0%D1%82%D1%8C-%D0%B3%D0%B8%D1%82%D0%B0%D1%80%D1%83.jpg"
          assert_correct_escaping(input, output)
        end

        should "correctly escapes square brackets" do
          input = "https://d.furaffinity.net/art/kinniro/1461084939/1461084939.kinniro_[commission]41.png"
          output = "https://d.furaffinity.net/art/kinniro/1461084939/1461084939.kinniro_%5Bcommission%5D41.png"
          assert_correct_escaping(input, output)
        end

        should "correctly escapes ＠" do
          input = "https://d.furaffinity.net/art/fr95/1635001690/1635001679.fr95_co＠f-r9512.png"
          output = "https://d.furaffinity.net/art/fr95/1635001690/1635001679.fr95_co%EF%BC%A0f-r9512.png"
          assert_correct_escaping(input, output)
        end
      end
    end
  end
end
