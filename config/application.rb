require_relative 'boot'
require "rails"
require "active_record/railtie"
#require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
#require "action_cable/engine"
#require "action_mailbox/engine"
#require "action_text/engine"
require "rails/test_unit/railtie"
#require "sprockets/railtie"

Bundler.require(*Rails.groups)

require_relative "danbooru_default_config"
require_relative "danbooru_local_config"

require 'elasticsearch/rails/instrumentation'

module Danbooru
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults '6.0'
    config.active_record.schema_format = :sql
    config.encoding = "utf-8"
    config.filter_parameters += [:password, :password_hash, :api_key]
    #config.assets.enabled = true
    #config.assets.version = '1.0'
    config.autoload_paths += %W(#{config.root}/app/presenters #{config.root}/app/logical #{config.root}/app/mailers #{config.root}/app/indexes)
    config.plugins = [:all]
    config.time_zone = 'UTC'
    config.action_mailer.perform_deliveries = true
    config.log_tags = [->(req) {"PID:#{Process.pid}"}]
    config.action_controller.action_on_unpermitted_parameters = :raise
    config.force_ssl = true
    config.active_job.queue_adapter = :sidekiq

    if Rails.env.production? && Danbooru.config.ssl_options.present?
      config.ssl_options = Danbooru.config.ssl_options
    else
      config.ssl_options = {
        hsts: false,
        secure_cookies: false,
        redirect: { exclude: ->(request) { true } }
      }
    end

    if File.exists?("#{config.root}/REVISION")
      config.x.git_hash = File.read("#{config.root}/REVISION").strip
    elsif system("type git > /dev/null && git rev-parse --show-toplevel > /dev/null")
      config.x.git_hash = %x(git rev-parse --short HEAD).strip
    else
      config.x.git_hash = nil
    end

    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: Danbooru.config.hostname,
      }
    end
  end

  I18n.enforce_available_locales = false
end
