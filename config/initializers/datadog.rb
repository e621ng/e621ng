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
