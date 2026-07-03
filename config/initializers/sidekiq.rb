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
    "IqdbConcurrencyResetJob" => {
      "cron" => "0 * * * *",
      "class" => "IqdbConcurrencyResetJob",
      "queue" => "low_prio",
      "description" => "Reset IQDB concurrent request counter to recover from worker crashes",
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
