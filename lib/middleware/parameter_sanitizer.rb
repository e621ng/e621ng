# frozen_string_literal: true

module Middleware
  # Rack middleware to sanitize request parameters by removing null bytes and invalid UTF-8.
  # This runs before Rails parameter parsing to prevent ArgumentError exceptions.
  # Also rejects oversized non-multipart bodies before they are read.
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

      # Uploads are multipart, so they keep the full nginx body limit.
      if content_type.exclude?("multipart/form-data") && env["CONTENT_LENGTH"].to_i > RequestLimits::BYTESIZE_LIMIT
        return payload_too_large(content_type)
      end

      if content_type.include?("application/x-www-form-urlencoded")
        body = read_body(env)
        return payload_too_large(content_type) if body.nil?
        if body.present?
          sanitized_body = sanitize_string(body)
          env["rack.input"] = StringIO.new(sanitized_body)
          env["CONTENT_LENGTH"] = sanitized_body.bytesize.to_s
        end
      elsif content_type.include?("application/json") && env["rack.input"]
        body = read_body(env)
        return payload_too_large(content_type) if body.nil?
        env["rack.input"] = StringIO.new(body)
        if body.present?
          begin
            JSON.parse(body, max_nesting: RequestLimits::DEPTH_LIMIT)
          rescue JSON::ParserError
            body = { success: false, message: "Invalid JSON body", code: nil }.to_json
            return [400, { "Content-Type" => "application/json" }, [body]]
          end
        end
      end

      @app.call(env)
    rescue URI::InvalidURIError
      [400, { "Content-Type" => "text/plain" }, ["Bad Request"]]
    end

    private

    # Bounded read, for bodies without a Content-Length. Returns nil when over the limit.
    def read_body(env)
      body = env["rack.input"].read(RequestLimits::BYTESIZE_LIMIT + 1) || ""
      body.bytesize > RequestLimits::BYTESIZE_LIMIT ? nil : body
    end

    def payload_too_large(content_type)
      if content_type.include?("application/json")
        body = { success: false, message: "Request body too large", code: nil }.to_json
        [413, { "Content-Type" => "application/json" }, [body]]
      else
        [413, { "Content-Type" => "text/plain" }, ["Request Entity Too Large"]]
      end
    end

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
