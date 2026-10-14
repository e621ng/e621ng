# frozen_string_literal: true

Datadog.configure do |c|
  c.tracing.enabled = !Rails.env.test? && ENV["DD_ENABLE"] == "true"
  c.logger.level = Logger::WARN

  c.tracing.instrument :rack, quantize: {
    query: {
      obfuscate: {
        regex: SensitiveParams.to_datadog_regex,
      },
    },
  }

  # Ignore pg errors during rack requests
  c.tracing.instrument :pg, on_error: ->(span, error) do
    if Datadog::Tracing.active_trace&.name != Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST
      span&.set_error(error)
    end
  end
end

# GitHelper is autoloaded from app/logical, so it isn't available while the
# initializer body runs. Defer setting the version tag until autoloading is
# ready. Tags traces with the deployed git version for Datadog deployment
# tracking.
Rails.application.config.after_initialize do
  Datadog.configure do |c|
    c.version = GitHelper.version.presence
  end
end
