# frozen_string_literal: true

module Middleware
  # Rack middleware to sanitize request parameters by removing null bytes and invalid UTF-8.
  # This runs before Rails parameter parsing to prevent ArgumentError exceptions.
  class ParameterSanitizer
    def initialize(app)
      @app = app
    end

    def call(env)
      env["QUERY_STRING"] = sanitize_string(env["QUERY_STRING"]) if env["QUERY_STRING"].present?
      env["REQUEST_URI"] = sanitize_string(env["REQUEST_URI"]) if env["REQUEST_URI"].present?
      env["REQUEST_PATH"] = sanitize_string(env["REQUEST_PATH"]) if env["REQUEST_PATH"].present?
      env["HTTP_COOKIE"] = sanitize_string(env["HTTP_COOKIE"]) if env["HTTP_COOKIE"].present?

      # For POST/PUT requests, sanitize the request body if it's form data
      if env["CONTENT_TYPE"]&.include?("application/x-www-form-urlencoded")
        body = env["rack.input"].read
        if body.present?
          sanitized_body = sanitize_string(body)
          env["rack.input"] = StringIO.new(sanitized_body)
          env["CONTENT_LENGTH"] = sanitized_body.bytesize.to_s
        end
      end

      @app.call(env)
    end

    private

    def sanitize_string(str)
      # NOTE: This handles the URL-encoded strings before Rails decodes them.
      # The controller-level sanitize_params handles the decoded parameters.
      str.dup.force_encoding("UTF-8").scrub("").delete("\u0000")
    rescue StandardError => e
      Rails.logger.warn("ParameterSanitizer: Failed to sanitize string: #{e.message}")
      ""
    end
  end
end
