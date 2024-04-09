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
end
