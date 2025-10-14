# frozen_string_literal: true

source "https://rubygems.org/"

gem "dotenv", require: "dotenv/load"

gem "rails", "~> 7.2.0"
gem "pg"
gem "dalli", platforms: :ruby
gem "simple_form"
gem "active_model_serializers", "~> 0.10.0"
gem "ruby-vips"
gem "bcrypt", require: "bcrypt"
gem "draper"
gem "streamio-ffmpeg"
gem "responders"
gem "dtext_rb", git: "https://github.com/e621ng/dtext_rb.git", branch: "master", require: "dtext"
gem "bootsnap"
gem "addressable"
gem "recaptcha", require: "recaptcha/rails"
gem "webpacker", ">= 4.0.x"
gem "sidekiq", "~> 7.0"
gem "marcel"
# bookmarks for later, if they are needed
# gem 'sidekiq-worker-killer'
gem "sidekiq-unique-jobs"
gem "redis"
gem "request_store"
gem "zxcvbn-ruby", require: "zxcvbn"

gem "diffy"
gem "rugged"

gem "datadog", require: "datadog/auto_instrument"

gem "opensearch-ruby"

gem "mailgun-ruby"

gem "faraday"
gem "faraday-follow_redirects"
gem "faraday-retry"

gem "rails-settings-cached", "~> 2.9"

group :production do
  gem "pitchfork"
end

group :development, :test do
  gem "listen"
  gem "puma"
end

group :development do
  gem "debug", require: false
  gem "rubocop", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-rails", require: false
  gem "rexml", ">= 3.4.2"
  gem "ruby-lsp"
  gem "ruby-lsp-rails", "~> 0.4.8"
  gem "faker", require: false
end

group :test do
  gem "shoulda-context", require: false
  gem "shoulda-matchers", require: false
  gem "factory_bot_rails", require: false
  gem "mocha", require: false
  gem "webmock", require: false
end
