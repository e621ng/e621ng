# frozen_string_literal: true

# Posts the daily janitor/moderator/AIBUR queue reports to their Discord
# webhooks. Not idempotent: a retry would post duplicate reports. Reports are
# isolated so one failed webhook doesn't skip the others, and each no-ops
# when its webhook URL is unconfigured.
class DiscordReportsJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options retry: false, lock: :until_executed

  REPORTS = [
    DiscordReport::JanitorStats,
    DiscordReport::ModeratorStats,
    DiscordReport::AiburStats,
  ].freeze

  def perform
    User.without_timeout do
      REPORTS.each do |report|
        report.new.run!
      rescue StandardError => e
        DanbooruLogger.log(e)
      end
    end
  end
end
