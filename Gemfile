source 'https://rubygems.org/'

gem 'dotenv-rails', require: 'dotenv/rails-now'

gem "rails", "~> 6.1"
gem "pg"
gem "dalli", :platforms => :ruby
gem "simple_form"
gem 'active_model_serializers', '~> 0.10.0'
gem "whenever", :require => false
gem "sanitize"
gem 'ruby-vips'
gem 'diff-lcs', :require => "diff/lcs/array"
gem 'bcrypt', :require => "bcrypt"
gem 'draper'
gem 'streamio-ffmpeg'
gem 'responders'
gem 'dtext_rb', :git => "https://github.com/zwagoth/dtext_rb.git", branch: "master", :require => "dtext"
gem 'cityhash'
gem 'memoist'
gem 'bootsnap'
gem 'addressable'
gem 'httparty'
gem 'recaptcha', require: "recaptcha/rails"
gem 'jquery-rails'
gem 'webpacker', '>= 4.0.x'
gem 'retriable'
gem 'sidekiq'
gem 'marcel'
# bookmarks for later, if they are needed
# gem 'sidekiq-worker-killer'
gem 'sidekiq-unique-jobs'
gem 'redis'
gem 'request_store'

gem 'elasticsearch-model'
gem 'elasticsearch-rails'

gem 'mailgun-ruby'
gem 'resolv'

group :production, :staging do
  gem 'unicorn', :platforms => :ruby
end

group :production do
  gem 'unicorn-worker-killer'
  gem 'newrelic_rpm'
end

group :development do
  gem 'sinatra'
end

group :development, :test do
  gem 'awesome_print'
  gem 'pry-byebug'
  gem 'listen'
end

group :test do
  gem "shoulda-context"
  gem "shoulda-matchers"
  gem "factory_bot"
  gem "mocha", :require => "mocha/minitest"
  gem "ffaker"
  gem "simplecov", :require => false
  gem "timecop"
  gem "webmock"
  gem "minitest-ci"
  gem "mock_redis"
end
