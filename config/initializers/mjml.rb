# frozen_string_literal: true

# MJML configuration
Mjml.setup do |config|
  # Use :erb as a template language
  config.template_language = :erb

  # Raise exceptions for template errors
  config.raise_render_exception = true

  # Beautify the output HTML
  config.beautify = true

  # Minify the output HTML
  config.minify = false

  # Validation level for MJML templates
  # Possible values: 'strict', 'soft'
  config.validation_level = "strict"

  # Use MRML instead of MJML (requires mrml gem)
  config.use_mrml = true

  # Cache compiled templates for better performance
  config.cache_mjml = false

  # Custom fonts configuration
  # Example: config.fonts = { Raleway: 'https://fonts.googleapis.com/css?family=Raleway' }
  config.fonts = nil

  # Uncomment this to enable template caching
  # config.cache_mjml = true
end
