# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::ParameterSanitizer do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(_env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] } }

  # Helper to call the middleware and return [status, headers, body_string, env]
  def call(env)
    result_env = nil
    inner_app = ->(e) {
      result_env = e
      app.call(e)
    }
    mw = described_class.new(inner_app)
    status, headers, body = mw.call(env)
    [status, headers, body, result_env]
  end

  def base_env(overrides = {})
    Rack::MockRequest.env_for("/", overrides)
  end

  # ---------------------------------------------------------------------------
  # URL env var sanitization
  # ---------------------------------------------------------------------------
  describe "URL environment variable sanitization" do
    %w[QUERY_STRING REQUEST_URI REQUEST_PATH HTTP_COOKIE].each do |key|
      describe key do
        it "removes null bytes" do
          env = base_env
          env[key] = "foo\u0000bar"
          _status, _headers, _body, received_env = call(env)
          expect(received_env[key]).to eq("foobar")
        end

        it "scrubs invalid UTF-8 bytes" do
          env = base_env
          env[key] = "valid\xFF\xFEtext".dup.force_encoding("BINARY")
          _status, _headers, _body, received_env = call(env)
          expect(received_env[key]).to eq("validtext")
        end

        it "leaves clean strings unchanged" do
          env = base_env
          env[key] = "clean_value=123"
          _status, _headers, _body, received_env = call(env)
          expect(received_env[key]).to eq("clean_value=123")
        end

        it "skips sanitization when blank" do
          env = base_env
          env[key] = ""
          expect { call(env) }.not_to raise_error
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # application/x-www-form-urlencoded body
  # ---------------------------------------------------------------------------
  describe "application/x-www-form-urlencoded body" do
    def form_env(body, content_type: "application/x-www-form-urlencoded")
      Rack::MockRequest.env_for(
        "/",
        method: "POST",
        "CONTENT_TYPE" => content_type,
        input: body,
      )
    end

    it "removes null bytes from the body" do
      env = form_env("name=fo\u0000o&bar=baz")
      _status, _headers, _body, received_env = call(env)
      expect(received_env["rack.input"].read).to eq("name=foo&bar=baz")
    end

    it "scrubs invalid UTF-8 bytes from the body" do
      raw = "name=\xFF\xFEvalue".dup.force_encoding("BINARY")
      env = form_env(raw)
      _status, _headers, _body, received_env = call(env)
      expect(received_env["rack.input"].read).to eq("name=value")
    end

    it "updates CONTENT_LENGTH after sanitization" do
      env = form_env("a=\u0000b")
      _status, _headers, _body, received_env = call(env)
      sanitized = received_env["rack.input"].read
      expect(received_env["CONTENT_LENGTH"].to_i).to eq(sanitized.bytesize)
    end

    it "leaves a clean body unchanged" do
      env = form_env("name=alice&age=30")
      _status, _headers, _body, received_env = call(env)
      expect(received_env["rack.input"].read).to eq("name=alice&age=30")
    end

    it "skips sanitization when body is empty" do
      env = form_env("")
      expect { call(env) }.not_to raise_error
    end

    it "passes the request through to the app" do
      env = form_env("key=value")
      status, _headers, _body, _env = call(env)
      expect(status).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # application/json body
  # ---------------------------------------------------------------------------
  describe "application/json body" do
    def json_env(body)
      Rack::MockRequest.env_for(
        "/",
        method: "POST",
        "CONTENT_TYPE" => "application/json",
        input: body,
      )
    end

    context "with valid JSON" do
      it "passes the request to the app and returns 200" do
        env = json_env('{"key":"value"}')
        status, _headers, _body, _env = call(env)
        expect(status).to eq(200)
      end

      it "rewinds the body so the downstream app can read it" do
        env = json_env('{"key":"value"}')
        _status, _headers, _body, received_env = call(env)
        expect(received_env["rack.input"].read).to eq('{"key":"value"}')
      end
    end

    context "with invalid JSON" do
      it "returns HTTP 400" do
        env = json_env("not json{{{")
        status, _headers, _body, _env = call(env)
        expect(status).to eq(400)
      end

      it "returns Content-Type: application/json" do
        env = json_env("bad json")
        _status, headers, _body, _env = call(env)
        expect(headers["Content-Type"]).to eq("application/json")
      end

      it "returns the expected error body" do
        env = json_env("bad json")
        _status, _headers, body, _env = call(env)
        parsed = JSON.parse(body.join)
        expect(parsed).to eq("success" => false, "message" => "Invalid JSON body", "code" => nil)
      end

      it "includes CORS headers" do
        env = json_env("bad json")
        _status, headers, _body, _env = call(env)
        expect(headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(headers["Access-Control-Allow-Headers"]).to eq("Authorization, User-Agent")
        expect(headers["Access-Control-Allow-Methods"]).to eq("POST, PUT, PATCH, DELETE, GET, HEAD, OPTIONS")
      end

      it "does not call the downstream app" do
        inner_app = instance_spy(Proc)
        mw = described_class.new(inner_app)
        mw.call(json_env("bad json"))
        expect(inner_app).not_to have_received(:call)
      end
    end

    context "with an empty body" do
      it "passes the request to the app without error" do
        env = json_env("")
        status, _headers, _body, _env = call(env)
        expect(status).to eq(200)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Other content types
  # ---------------------------------------------------------------------------
  describe "other content types" do
    it "passes multipart/form-data requests straight through without processing the body" do
      env = Rack::MockRequest.env_for(
        "/",
        method: "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=----boundary",
        input: "raw multipart body",
      )
      status, _headers, _body, received_env = call(env)
      expect(status).to eq(200)
      expect(received_env["rack.input"].read).to eq("raw multipart body")
    end

    it "passes text/plain requests straight through" do
      env = Rack::MockRequest.env_for(
        "/",
        method: "POST",
        "CONTENT_TYPE" => "text/plain",
        input: "hello world",
      )
      status, _headers, _body, _env = call(env)
      expect(status).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # URI::InvalidURIError rescue path
  # ---------------------------------------------------------------------------
  describe "URI::InvalidURIError handling" do
    it "returns 400 plain text when the downstream app raises URI::InvalidURIError" do
      inner_app = ->(_e) { raise URI::InvalidURIError, "bad URI" }
      mw = described_class.new(inner_app)
      status, headers, body = mw.call(base_env)
      expect(status).to eq(400)
      expect(headers["Content-Type"]).to eq("text/plain")
      expect(body).to eq(["Bad Request"])
    end
  end

  # ---------------------------------------------------------------------------
  # sanitize_string rescue path
  # ---------------------------------------------------------------------------
  describe "sanitize_string error handling" do
    it "logs a warning and returns an empty string when an unexpected error occurs" do
      # Use a custom object whose #dup raises so the rescue branch is exercised
      # without relying on allow_any_instance_of(String).
      bad_input = Object.new
      def bad_input.dup
        raise StandardError, "boom"
      end

      allow(Rails.logger).to receive(:warn)
      result = middleware.send(:sanitize_string, bad_input)
      expect(Rails.logger).to have_received(:warn).with(/ParameterSanitizer.*boom/)
      expect(result).to eq("")
    end
  end
end
