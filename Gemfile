# frozen_string_literal: true

source "https://rubygems.org/"

# Must stay first: populates ENV before any other gem is required.
gem "dotenv", "3.1.0", require: "dotenv/load"

# Framework
gem "rails", "8.1.4.1"
gem "bootsnap", "1.26.1"
gem "rack-cors", "3.0.0"
gem "rails-settings-cached", "2.10.0"
gem "request_store", "1.7.0"
gem "responders", "3.1.1"

# Data stores
gem "dalli", "3.2.8"
gem "opensearch-ruby", "3.2.0"
gem "pg", "1.5.6"
gem "redis", "5.2.0"

# Background jobs
gem "sidekiq", "8.1.2"
gem "sidekiq-cron", "2.4.0"
gem "sidekiq-unique-jobs", "8.1.0"

# Views and serialization
gem "blueprinter", "1.2.1"
gem "draper", "4.0.2"
gem "simple_form", "5.3.0"
gem "sitemap_generator", "7.0.1"
gem "view_component", "4.12.0"
gem "vite_rails", "3.10.0"

# Text processing and versioning
gem "diffy", "3.4.2"
gem "rugged", "1.7.2"

# Set LOCAL_DTEXT=true to develop against a checkout in vendor/dtext
if ENV["LOCAL_DTEXT"] == "true" && File.directory?("vendor/dtext")
  gem "dtext", path: "vendor/dtext"
else
  gem "dtext", "2.0.6"
end

# Media
gem "marcel", "1.2.1"
gem "ruby-vips", "2.2.1"
gem "streamio-ffmpeg", "3.0.2"

# Authentication
gem "bcrypt", "3.1.22"
gem "doorkeeper", "5.9.1"
gem "doorkeeper-openid_connect", "1.10.1"
gem "rotp", "6.3.0"
gem "rqrcode", "3.2.0"
gem "zxcvbn-ruby", "1.2.0", require: "zxcvbn"

# Email
gem "mailgun-ruby", "1.2.14"
gem "mjml-rails", "4.16.0"
gem "mrml", "1.8.1"

# Outbound HTTP
gem "addressable", "2.9.0"
gem "faraday", "2.14.3"
gem "faraday-follow_redirects", "0.3.0"
gem "faraday-retry", "2.2.1"

# Monitoring
gem "datadog", "2.38.0", require: "datadog/auto_instrument"

group :production do
  gem "pitchfork", "0.13.0"
end

group :development, :test do
  gem "listen", "3.9.0"
  gem "puma", "8.0.2"

  # Testing
  gem "factory_bot_rails", "6.4.3", require: false
  gem "parallel_tests", "5.6.0"
  gem "rspec-rails", "8.0.4", require: false
  gem "rspec-sidekiq", "5.3.0", require: false
  gem "simplecov", "0.22.0", require: false
  gem "simplecov_json_formatter", "0.1.4", require: false
  gem "webmock", "3.26.2", require: false

  # Used by both tests and db/populate.rb
  gem "faker", "3.4.2", require: false
end

group :development do
  gem "debug", "1.9.2", require: false

  # Linting
  gem "rubocop", "1.63.4", require: false
  gem "rubocop-erb", "0.4.0", require: false
  gem "rubocop-rails", "2.24.1", require: false
  gem "rubocop-rspec", "3.4.0", require: false
  gem "rubocop-rspec_rails", "2.30.0", require: false

  # Editor tooling
  gem "ruby-lsp", "0.26.9"
  gem "ruby-lsp-rails", "0.4.8"
  gem "ruby-lsp-rspec", "0.1.29", require: false

  # Must stay below pg, which it patches
  gem "rack-mini-profiler", "4.0.1"
end
