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

      content_type = env["CONTENT_TYPE"].to_s

      if content_type.include?("application/x-www-form-urlencoded")
        body = env["rack.input"].read
        if body.present?
          sanitized_body = sanitize_string(body)
          env["rack.input"] = StringIO.new(sanitized_body)
          env["CONTENT_LENGTH"] = sanitized_body.bytesize.to_s
        end
      elsif content_type.include?("application/json") && env["rack.input"]
        body = env["rack.input"].read
        env["rack.input"] = StringIO.new(body)
        if body.present?
          begin
            JSON.parse(body)
          rescue JSON::ParserError
            headers = {
              "Content-Type" => "application/json",
              "Access-Control-Allow-Origin" => "*",
              "Access-Control-Allow-Headers" => "Authorization, User-Agent",
              "Access-Control-Allow-Methods" => "POST, PUT, PATCH, DELETE, GET, HEAD, OPTIONS",
            }
            body = { success: false, message: "Invalid JSON body", code: nil }.to_json
            return [400, headers, [body]]
          end
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
