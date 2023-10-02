source 'https://rubygems.org/'

gem 'dotenv-rails', require: 'dotenv/rails-now'

gem "rails", "~> 7.0"
gem "pg"
gem "dalli", :platforms => :ruby
gem "simple_form"
gem 'active_model_serializers', '~> 0.10.0'
gem 'ruby-vips'
gem 'diff-lcs', :require => "diff/lcs/array"
gem 'bcrypt', :require => "bcrypt"
gem 'draper'
gem 'streamio-ffmpeg'
gem 'responders'
gem 'dtext_rb', :git => "https://github.com/e621ng/dtext_rb.git", branch: "master", :require => "dtext"
gem 'memoist'
gem 'bootsnap'
gem 'addressable'
gem 'httparty'
gem 'recaptcha', require: "recaptcha/rails"
gem 'webpacker', '>= 4.0.x'
gem 'retriable'
gem 'sidekiq', '~> 7.0'
gem 'marcel'
# bookmarks for later, if they are needed
# gem 'sidekiq-worker-killer'
gem 'sidekiq-unique-jobs'
gem 'redis'
gem 'request_store'

gem 'opensearch-ruby'

gem 'mailgun-ruby'
gem 'resolv'

group :production do
  gem 'unicorn'
  gem 'unicorn-worker-killer'
  gem 'newrelic_rpm'
end

group :development, :test do
  gem 'listen'
  gem 'puma'
end

group :docker do
  gem "rubocop", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-rails", require: false
  gem "solargraph", require: false
end

group :test do
  gem "shoulda-context", require: false
  gem "shoulda-matchers", require: false
  gem "factory_bot_rails", require: false
  gem "mocha", require: false
  gem "webmock", require: false
end
