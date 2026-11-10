# frozen_string_literal: true

require "rails_helper"

# config/initializers/request_limits.rb applies Rack's form limits to GET query strings and JSON bodies.
RSpec.describe "Request parameter limits" do
  describe "GET query strings" do
    let(:path) { keyboard_shortcuts_path }

    def query(count)
      (1..count).map { |i| "a#{i}=1" }.join("&")
    end

    def nested_query(depth)
      "a#{'[a]' * depth}=1"
    end

    it "accepts the maximum number of parameters" do
      get "#{path}?#{query(RequestLimits::PARAMS_LIMIT)}"
      expect(response).to have_http_status(:ok)
    end

    it "rejects too many parameters" do
      get "#{path}?#{query(RequestLimits::PARAMS_LIMIT + 1)}"
      expect(response).to have_http_status(:bad_request)
    end

    it "accepts shallowly nested parameters" do
      get "#{path}?#{nested_query(5)}"
      expect(response).to have_http_status(:ok)
    end

    it "rejects parameters nested deeper than the limit" do
      get "#{path}?#{nested_query(RequestLimits::DEPTH_LIMIT + 8)}"
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "JSON bodies" do
    # Anonymous, so logged_in_only answers 403 once the params have parsed.
    def post_json(body)
      post dtext_preview_path(format: :json), params: body, headers: { "CONTENT_TYPE" => "application/json" }
    end

    def json_object(count)
      (1..count).to_h { |i| ["a#{i}", 1] }.to_json
    end

    it "accepts the maximum number of parameters" do
      post_json(json_object(RequestLimits::PARAMS_LIMIT))
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects too many top-level parameters" do
      post_json(json_object(RequestLimits::PARAMS_LIMIT + 1))
      expect(response).to have_http_status(:bad_request)
    end

    it "counts nested parameters" do
      post_json({ a: JSON.parse(json_object(RequestLimits::PARAMS_LIMIT)) }.to_json)
      expect(response).to have_http_status(:bad_request)
    end

    it "counts array elements" do
      post_json({ ids: Array.new(RequestLimits::PARAMS_LIMIT, 1) }.to_json)
      expect(response).to have_http_status(:bad_request)
    end

    it "counts the elements of a top-level array" do
      post_json(Array.new(RequestLimits::PARAMS_LIMIT + 1, 1).to_json)
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects JSON nested deeper than the limit" do
      depth = RequestLimits::DEPTH_LIMIT + 1
      post_json("#{'[' * depth}1#{']' * depth}")
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "rejects oversized non-multipart bodies" do
    post dtext_preview_path(format: :json), params: { body: "a" * (RequestLimits::BYTESIZE_LIMIT + 1) }.to_json,
                                            headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:content_too_large)
  end
end
