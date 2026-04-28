# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbQueriesController do
  include_context "as admin"

  before do
    allow(IqdbProxy).to receive(:enabled?).and_return(true)
    allow(RateLimiter).to receive(:check_limit).and_return(false)
    allow(RateLimiter).to receive(:hit)
  end

  # ---------------------------------------------------------------------------
  # Feature gate
  # ---------------------------------------------------------------------------

  describe "GET /iqdb_queries — feature disabled" do
    before { allow(IqdbProxy).to receive(:enabled?).and_return(false) }

    it "returns 400" do
      get iqdb_queries_path
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ---------------------------------------------------------------------------
  # No search params
  # ---------------------------------------------------------------------------

  describe "GET /iqdb_queries — no search params" do
    it "returns 200" do
      get iqdb_queries_path
      expect(response).to have_http_status(:ok)
    end

    it "returns an empty array as JSON" do
      get iqdb_queries_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "does not call RateLimiter when no search params are present" do
      get iqdb_queries_path
      expect(RateLimiter).not_to have_received(:check_limit)
    end
  end

  # ---------------------------------------------------------------------------
  # post_id param
  # ---------------------------------------------------------------------------

  describe "GET /iqdb_queries — post_id param" do
    let(:post) { create(:post) }

    before { allow(IqdbProxy).to receive(:query_post).and_return([]) }

    it "returns 200 for a valid numeric post_id" do
      get iqdb_queries_path, params: { post_id: post.id }
      expect(response).to have_http_status(:ok)
    end

    it "delegates to IqdbProxy.query_post" do
      get iqdb_queries_path, params: { post_id: post.id }
      expect(IqdbProxy).to have_received(:query_post)
    end

    it "returns 400 for a non-numeric post_id" do
      get iqdb_queries_path, params: { post_id: "abc" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 200 using the search[] namespace" do
      get iqdb_queries_path, params: { search: { post_id: post.id } }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # hash param
  # ---------------------------------------------------------------------------

  describe "GET /iqdb_queries — hash param" do
    before { allow(IqdbProxy).to receive(:query_hash).and_return([]) }

    it "returns 200 for a valid hex hash" do
      get iqdb_queries_path, params: { hash: "deadbeef" }
      expect(response).to have_http_status(:ok)
    end

    it "returns an empty array as JSON" do
      get iqdb_queries_path(format: :json), params: { hash: "deadbeef" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns 400 for a non-hex hash" do
      get iqdb_queries_path, params: { hash: "not-valid!" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 200 using uppercase hex characters" do
      get iqdb_queries_path, params: { hash: "DEADBEEF" }
      expect(response).to have_http_status(:ok)
    end

    it "delegates to IqdbProxy.query_hash" do
      get iqdb_queries_path, params: { hash: "deadbeef" }
      expect(IqdbProxy).to have_received(:query_hash)
    end
  end

  # ---------------------------------------------------------------------------
  # url param
  # ---------------------------------------------------------------------------

  describe "GET /iqdb_queries — url param" do
    before do
      allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([true, "ok"])
      allow(IqdbProxy).to receive(:query_url).and_return([])
    end

    it "returns 200 for a whitelisted URL" do
      get iqdb_queries_path, params: { url: "https://example.com/image.jpg" }
      expect(response).to have_http_status(:ok)
    end

    it "delegates to IqdbProxy.query_url" do
      get iqdb_queries_path, params: { url: "https://example.com/image.jpg" }
      expect(IqdbProxy).to have_received(:query_url)
    end

    it "returns 400 for a non-whitelisted URL" do
      allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([false, "not in whitelist"])
      get iqdb_queries_path, params: { url: "https://example.com/image.jpg" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when url param is not a string (nested hash)" do
      # Passing url as a nested hash makes it non-String, triggering the type guard
      get iqdb_queries_path, params: { url: { nested: "value" } }
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ---------------------------------------------------------------------------
  # file param (POST)
  # ---------------------------------------------------------------------------

  describe "POST /iqdb_queries — file param" do
    before { allow(IqdbProxy).to receive(:query_file).and_return([]) }

    it "returns 200 for a valid uploaded file" do
      file = fixture_file_upload("spec/fixtures/files/sample.jpg", "image/jpeg")
      post iqdb_queries_path, params: { file: file }
      expect(response).to have_http_status(:ok)
    end

    it "delegates to IqdbProxy.query_file" do
      file = fixture_file_upload("spec/fixtures/files/sample.jpg", "image/jpeg")
      post iqdb_queries_path, params: { file: file }
      expect(IqdbProxy).to have_received(:query_file)
    end

    it "returns 400 when file param is a plain string" do
      post iqdb_queries_path, params: { file: "not-a-file" }
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /iqdb_queries (general)
  # ---------------------------------------------------------------------------

  describe "POST /iqdb_queries" do
    before { allow(IqdbProxy).to receive(:query_hash).and_return([]) }

    it "returns 200" do
      post iqdb_queries_path, params: { hash: "deadbeef" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  describe "error handling" do
    it "returns 404 on Downloads::File::Error" do
      allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([true, "ok"])
      allow(IqdbProxy).to receive(:query_url).and_raise(Downloads::File::Error, "not found")
      get iqdb_queries_path, params: { url: "https://example.com/image.jpg" }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 500 on IqdbProxy::Error" do
      allow(IqdbProxy).to receive(:query_hash).and_raise(IqdbProxy::Error, "service unavailable")
      get iqdb_queries_path, params: { hash: "deadbeef" }
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  # ---------------------------------------------------------------------------
  # Throttling
  # ---------------------------------------------------------------------------

  describe "throttling" do
    before do
      allow(IqdbProxy).to receive(:query_hash).and_return([])
      allow(RateLimiter).to receive(:check_limit).and_return(true)
    end

    it "returns 429 when the rate limit is exceeded" do
      get iqdb_queries_path, params: { hash: "deadbeef" }
      expect(response).to have_http_status(:too_many_requests)
    end

    it "checks the rate limit keyed by IP address" do
      get iqdb_queries_path, params: { hash: "deadbeef" }
      expect(RateLimiter).to have_received(:check_limit).with("img:127.0.0.1", 1, 2.seconds)
    end
  end
end
