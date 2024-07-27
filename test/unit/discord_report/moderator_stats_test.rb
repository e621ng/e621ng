# frozen_string_literal: true

require "test_helper"

module DiscordReport
  class ModeratorStatsTest < ActiveSupport::TestCase
    test "it works" do
      ModeratorStats.new.report # Prime cache
      stats = ModeratorStats.new
      stats.stubs(:webhook_url).returns("https://example.com")
      stub_request(:post, "https://example.com/")
        .with(body: /Moderator report for/, headers: { "Content-Type" => "application/json" })
      stats.post_webhook
    end
  end
end
