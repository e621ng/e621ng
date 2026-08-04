# frozen_string_literal: true

require "sidekiq-unique-jobs"
require "sidekiq-cron"

Sidekiq.logger.level = Logger::WARN if Rails.env.test?

Sidekiq.configure_server do |config| # rubocop:disable Metrics/BlockLength
  config.redis = { url: Danbooru.config.redis_url }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)

  # Schedule recurring jobs
  schedule = {
    "SearchTrendAggregateJob" => {
      "cron" => "30 * * * *", # Every hour at minute 30
      "class" => "SearchTrendAggregateJob",
      "description" => "Aggregate unprocessed hourly search trends into daily totals",
    },
    "SearchTrendCacheWarmJob" => {
      "cron" => "*/15 * * * *",
      "class" => "SearchTrendCacheWarmJob",
      "queue" => "low_prio",
      "description" => "Pre-warm the rising tags cache every 15 minutes to avoid on-request timeouts",
    },
    "SitemapGeneratorJob" => {
      "cron" => "30 0 * * *", # Every day at 30 minutes past midnight
      "class" => "SitemapGeneratorJob",
      "queue" => "low_prio",
      "description" => "Generate the sitemap.xml file for search engines",
    },
    "DbExportJob" => {
      "cron" => "0 4 * * *", # Every day at 4:00 AM
      "class" => "DbExportJob",
      "queue" => "low_prio",
      "description" => "Generate the daily public database exports",
    },
    "AsnRangesUpdateJob" => {
      "cron" => "0 3 2 * *", # Monthly on the 2nd at 3:00 AM
      "class" => "AsnRangesUpdateJob",
      "queue" => "low_prio",
      "description" => "Refresh the IP-to-ASN dataset from iptoasn.com",
    },
    "IqdbConcurrencyResetJob" => {
      "cron" => "0 * * * *",
      "class" => "IqdbConcurrencyResetJob",
      "queue" => "low_prio",
      "description" => "Reset IQDB concurrent request counter to recover from worker crashes",
    },
    "DailyPruneJob" => {
      "cron" => "0 1 * * *", # Every day at 1:00 AM
      "class" => "DailyPruneJob",
      "queue" => "low_prio",
      "description" => "Prune expired uploads, bans, nonces, and exception logs; fix stale counts and flags",
    },
    "StatsUpdateJob" => {
      "cron" => "0 1 * * *", # Every day at 1:00 AM
      "class" => "StatsUpdateJob",
      "queue" => "low_prio",
      "description" => "Recalculate and cache the site-wide statistics",
    },
    "PostPruneJob" => {
      "cron" => "10 1 * * *", # Every day at 1:10 AM
      "class" => "PostPruneJob",
      "queue" => "low_prio",
      "description" => "Delete pending posts that were not approved within the moderation window",
    },
    "ForumSubscriptionMailJob" => {
      "cron" => "20 1 * * *", # Every day at 1:20 AM
      "class" => "ForumSubscriptionMailJob",
      "queue" => "low_prio",
      "description" => "Send forum topic digest emails to subscribed users",
    },
    "DiscordReportsJob" => {
      "cron" => "30 1 * * *", # Every day at 1:30 AM
      "class" => "DiscordReportsJob",
      "queue" => "low_prio",
      "description" => "Post the daily janitor/moderator/AIBUR queue reports to Discord",
    },
    "ApiKeyExpirationWarningJob" => {
      "cron" => "40 1 * * *", # Every day at 1:40 AM
      "class" => "ApiKeyExpirationWarningJob",
      "queue" => "low_prio",
      "description" => "Warn users about API keys that are about to expire",
    },
    "SearchTrendPruneJob" => {
      "cron" => "50 1 * * *", # Every day at 1:50 AM
      "class" => "SearchTrendPruneJob",
      "queue" => "low_prio",
      "description" => "Prune old hourly and daily search trend records",
    },
    "UserIpAddressPruneJob" => {
      "cron" => "0 2 * * *", # Every day at 2:00 AM
      "class" => "UserIpAddressPruneJob",
      "queue" => "low_prio",
      "description" => "Prune user IP address rows unseen for the retention period",
    },
  }

  Sidekiq::Cron::Job.load_from_hash schedule
end

Sidekiq.configure_client do |config|
  config.redis = { url: Danbooru.config.redis_url }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end
