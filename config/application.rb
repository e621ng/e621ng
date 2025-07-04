# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "danbooru_default_config"
require_relative "danbooru_local_config"

module Danbooru
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # https://github.com/rails/rails/issues/50897
    config.active_record.raise_on_assign_to_attr_readonly = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # config.autoload_lib(ignore: %w(assets tasks))

    config.active_record.schema_format = :sql
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

    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: Danbooru.config.hostname,
      }
    end

    config.i18n.enforce_available_locales = false
    config.active_model.i18n_customize_full_message = true

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
