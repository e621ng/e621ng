# frozen_string_literal: true

# Supply-chain quarantine: never resolve a gem version published less than 3 days ago.
# Bypass with `--cooldown 0` only for a justified critical security fix.
source "https://rubygems.org/", cooldown: 3

# Must stay first: populates ENV before any other gem is required.
gem "dotenv", "3.2.0", require: "dotenv/load"

### Framework
gem "rails", "8.1.4.1"
gem "bootsnap", "1.26.1"
gem "rack-cors", "3.0.0"
gem "rails-settings-cached", "2.10.0"
gem "request_store", "1.7.0"
gem "responders", "3.2.1"
# Nothing depends on these since rdoc 8; unpinned, Ruby's older bundled psych/stringio would load instead
gem "psych", "5.5.0"
gem "stringio", "3.2.0"

### Data stores
gem "dalli", "3.2.15" # Held on 3.2.x: 5.x needs memcached 1.6+ and 4.x+ crashes Ruby < 3.3.8 (bug #21195)
gem "opensearch-ruby", "3.4.0"
gem "pg", "1.7.0"
gem "redis", "6.0.0"

### Background jobs
gem "sidekiq", "8.1.7"
gem "sidekiq-cron", "2.4.0"
gem "sidekiq-unique-jobs", "8.1.0"

### Views and serialization
gem "blueprinter", "1.3.0"
gem "draper", "4.0.6"
gem "simple_form", "5.4.1"
gem "sitemap_generator", "7.1.1"
gem "view_component", "4.23.0"
gem "vite_rails", "3.11.1"

### Text processing and versioning
gem "diffy", "3.4.4"
gem "rugged", "1.9.6"

# Set LOCAL_DTEXT=true to develop against a checkout in vendor/dtext
if ENV["LOCAL_DTEXT"] == "true" && File.directory?("vendor/dtext")
  gem "dtext", path: "vendor/dtext"
else
  gem "dtext", "2.0.7"
end

### Media
gem "marcel", "1.2.1" # Held on 1.x: activestorage requires marcel ~> 1.0, even though it isn't loaded

### Authentication
gem "bcrypt", "3.1.22"
gem "doorkeeper", "5.9.9"
gem "doorkeeper-openid_connect", "2.1.0"
gem "rotp", "6.4.0"
gem "rqrcode", "3.2.0"
gem "zxcvbn-ruby", "2.0.1", require: "zxcvbn"

### Email
gem "mailgun-ruby", "1.4.6"
gem "mjml-rails", "5.0.0"
gem "mrml", "1.10.0"

### Outbound HTTP
gem "addressable", "2.9.2"
gem "faraday", "2.15.1"
gem "faraday-follow_redirects", "0.5.0"
gem "faraday-retry", "2.4.0"

### Monitoring
gem "datadog", "2.48.0", require: "datadog/auto_instrument"

group :production do
  gem "pitchfork", "0.18.2"
end

group :development, :test do
  gem "listen", "3.10.1"
  gem "puma", "8.0.2"

  ### Testing
  gem "factory_bot_rails", "6.5.1", require: false
  gem "parallel_tests", "5.9.0"
  gem "rspec-rails", "8.1.0", require: false
  gem "rspec-sidekiq", "5.3.0", require: false
  gem "simplecov", "1.3.2", require: false
  gem "webmock", "3.34.0", require: false

  # Used by both tests and db/populate.rb
  gem "faker", "3.8.0", require: false
end

group :development do
  gem "debug", "1.11.1", require: false

  ### Linting
  gem "rubocop", "1.92.2", require: false
  gem "rubocop-erb", "0.8.2", require: false
  gem "rubocop-rails", "2.38.0", require: false
  gem "rubocop-rspec", "3.10.2", require: false
  gem "rubocop-rspec_rails", "2.33.0", require: false

  ### Editor tooling
  gem "ruby-lsp", "0.26.11"
  gem "ruby-lsp-rails", "0.4.8"
  gem "ruby-lsp-rspec", "0.1.29", require: false

  # Must stay below pg, which it patches
  gem "rack-mini-profiler", "5.0.0"
end
