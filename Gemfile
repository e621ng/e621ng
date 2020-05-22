source 'https://rubygems.org/'

gem 'dotenv-rails', require: 'dotenv/rails-now'

gem "rails", "~> 6.0"
gem "pg"
gem "dalli", :platforms => :ruby
gem "simple_form"
gem "mechanize"
gem 'active_model_serializers', '~> 0.10.0'
gem "whenever", :require => false
gem "sanitize"
gem 'ruby-vips'
gem 'net-sftp'
gem 'diff-lcs', :require => "diff/lcs/array"
gem 'bcrypt', :require => "bcrypt"
gem 'draper'
gem 'statistics2'
gem 'capistrano', '~> 3.10'
gem 'capistrano-rails'
gem 'capistrano-rbenv'
gem 'radix62', '~> 1.0.1'
gem 'streamio-ffmpeg'
gem 'rubyzip', :require => "zip"
gem 'twitter'
gem 'responders'
gem 'dtext_rb', :git => "https://github.com/zwagoth/dtext_rb.git", branch: "master", :require => "dtext"
gem 'cityhash'
gem 'memoist'
gem 'daemons'
gem 'oauth2'
gem 'bootsnap'
gem 'addressable'
gem 'httparty'
gem 'rakismet'
gem 'recaptcha', require: "recaptcha/rails"
gem 'ptools'
gem 'jquery-rails'
gem 'webpacker', '>= 4.0.x'
gem 'retriable'
gem 'sidekiq'
# bookmarks for later, if they are needed
# gem 'sidekiq-worker-killer'
gem 'sidekiq-unique-jobs'
gem 'redis'
gem 'request_store'

gem 'elasticsearch-model'
gem 'elasticsearch-rails'


gem 'mailgun-ruby'

# needed for looser jpeg header compat
gem 'ruby-imagespec', :require => "image_spec", :git => "https://github.com/r888888888/ruby-imagespec.git", :branch => "exif-fixes"

group :production, :staging do
  gem 'unicorn', :platforms => :ruby
  gem 'capistrano3-unicorn'
end

group :production do
  gem 'unicorn-worker-killer'
  gem 'newrelic_rpm'
  gem 'capistrano-deploytags', '~> 1.0.0', require: false
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
  gem "mocha", :require => "mocha/setup"
  gem "ffaker"
  gem "simplecov", :require => false
  gem "timecop"
  gem "webmock"
  gem "minitest-ci"
  gem "mock_redis"
end
