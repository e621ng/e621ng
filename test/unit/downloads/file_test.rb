require 'test_helper'

module Downloads
  class FileTest < ActiveSupport::TestCase
    context "A post download" do
      setup do
        CurrentUser.user = create(:user)
        CloudflareService.stubs(:ips).returns([])
        UploadWhitelist.stubs(:is_whitelisted?).returns(true)
        @source = "http://www.google.com/intl/en_ALL/images/logo.gif"
        @download = Downloads::File.new(@source)
        f = Tempfile.new
        IO.copy_stream("#{Rails.root}/test/files/test.jpg", f.path)
        stub_request(:get, @source).to_return(status: 200, body: f.read, headers: {})
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
    end
  end
end
