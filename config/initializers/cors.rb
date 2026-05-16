# frozen_string_literal: true

# Insert Rack::Cors above the ParameterSanitizer so it wraps every response,
# including early rejections from the sanitizer and any controller that does
# not inherit from ApplicationController (e.g. Rails::HealthController at
# /status).
Rails.application.config.middleware.insert_before Middleware::ParameterSanitizer, Rack::Cors do
  allow do
    origins "*"

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end
