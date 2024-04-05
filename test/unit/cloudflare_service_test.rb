# frozen_string_literal: true

require "test_helper"

class CloudflareServiceTest < ActiveSupport::TestCase
  context "#ips" do
    should "work" do
      ipv4 = "173.245.48.0/20"
      ipv6 = "2400:cb00::/32"
      dummy_response = {
        result: {
          ipv4_cidrs: [ipv4],
          ipv6_cidrs: [ipv6],
        },
      }
      stub_request(:get, "https://api.cloudflare.com/client/v4/ips").to_return(status: 200, body: dummy_response.to_json)
      assert_equal([IPAddr.new(ipv4), IPAddr.new(ipv6)], CloudflareService.ips)
    end
  end
end
