# frozen_string_literal: true

require "test_helper"

module DiscordReport
  class JanitorStatsTest < ActiveSupport::TestCase
    test "it works" do
      assert_nothing_raised do
        JanitorStats.new.report # Prime cache
        stats = JanitorStats.new
        stats.stubs(:webhook_url).returns("https://example.com")
        stub_request(:post, "https://example.com/")
          .with(body: /Janitor report for/, headers: { "Content-Type" => "application/json" })
        stats.post_webhook
      end
    end
  end
end
