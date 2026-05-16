# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pagination parameter validation" do
  include_context "as member"

  describe "limit" do
    it "accepts a valid integer string" do
      get notes_path, params: { limit: "20" }
      expect(response).to have_http_status(:ok)
    end

    it "falls back to default when blank" do
      get notes_path, params: { limit: "" }
      expect(response).to have_http_status(:ok)
    end

    it "rejects negative values" do
      get notes_path, params: { limit: "-1" }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid limit")
    end

    it "rejects float strings" do
      get notes_path, params: { limit: "10.5" }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid limit")
    end

    it "rejects non-numeric strings" do
      get notes_path, params: { limit: "abc" }
      expect(response).to have_http_status(:gone)
    end

    it "rejects values above the configured maximum" do
      get notes_path, params: { limit: (Danbooru.config.max_per_page + 1).to_s }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Limit must be between")
    end

    it "rejects hash-valued limit" do
      get notes_path, params: { limit: { test: "10" } }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid limit")
    end

    it "rejects array-valued limit" do
      get notes_path, params: { limit: ["10"] }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid limit")
    end
  end

  describe "page" do
    it "accepts a valid numbered page" do
      get notes_path, params: { page: "1" }
      expect(response).to have_http_status(:ok)
    end

    it "falls back to page 1 when blank" do
      get notes_path, params: { page: "" }
      expect(response).to have_http_status(:ok)
    end

    it "rejects page 0" do
      get notes_path, params: { page: "0" }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid page number")
    end

    it "rejects negative pages" do
      get notes_path, params: { page: "-1" }
      expect(response).to have_http_status(:gone)
    end

    it "rejects pages beyond max_numbered_pages" do
      get notes_path, params: { page: (Danbooru.config.max_numbered_pages + 1).to_s }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("cannot go beyond")
    end

    it "rejects float pages" do
      get notes_path, params: { page: "10.5" }
      expect(response).to have_http_status(:gone)
    end

    it "rejects non-numeric pages" do
      get notes_path, params: { page: "abc" }
      expect(response).to have_http_status(:gone)
    end

    it "accepts sequential pages" do
      get notes_path, params: { page: "a100" }
      expect(response).to have_http_status(:ok)

      get notes_path, params: { page: "b100" }
      expect(response).to have_http_status(:ok)
    end

    it "rejects sequential ids beyond 32-bit integer max" do
      get notes_path, params: { page: "a2147483648" }
      expect(response).to have_http_status(:gone)
    end

    it "rejects malformed sequential pages" do
      get notes_path, params: { page: "a-1" }
      expect(response).to have_http_status(:gone)

      get notes_path, params: { page: "a26.5" }
      expect(response).to have_http_status(:gone)

      get notes_path, params: { page: "a123foo" }
      expect(response).to have_http_status(:gone)
    end

    it "rejects hash-valued page" do
      get notes_path, params: { page: { test: "10" } }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid page number")
    end

    it "rejects array-valued page" do
      get notes_path, params: { page: ["10"] }
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("Invalid page number")
    end
  end
end
