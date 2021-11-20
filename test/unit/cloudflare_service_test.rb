require 'test_helper'
require 'webmock/minitest'

class CloudflareServiceTest < ActiveSupport::TestCase
  subject { CloudflareService.new }

  context "#ips" do
    should "work" do
      refute_empty(subject.ips)
    end
  end
end
