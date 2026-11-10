# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Oversized GET parameter rejection" do
  let(:over) { "a" * (ApplicationController::MAX_GET_PARAMETER_LENGTH + 1) }
  let(:at_limit) { "a" * ApplicationController::MAX_GET_PARAMETER_LENGTH }

  it "accepts a normal-sized query" do
    get posts_path, params: { tags: "cat" }
    expect(response).to have_http_status(:ok)
  end

  it "accepts a value exactly at the limit" do
    get posts_path, params: { tags: at_limit }
    expect(response).to have_http_status(:ok)
  end

  it "rejects a top-level value over the limit" do
    get posts_path, params: { tags: over }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("too long")
  end

  it "rejects an oversized value nested in an array" do
    get posts_path, params: { tags: [over] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an oversized value nested in a hash" do
    get posts_path, params: { search: { tags: over } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  # Regression test for E6SEC-101: a POST overridden to GET smuggles the oversized
  # value through the body, bypassing the URL-length cap. The guard must still fire.
  it "rejects an oversized value smuggled via X-HTTP-Method-Override: GET" do
    post posts_path, params: { _method: "GET", tags: over }, headers: { "X-HTTP-Method-Override" => "GET" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("too long")
  end

  # Regression test for E6SEC-003: >1024 distinct free `rating:` tokens fit under the cap and used
  # to exceed OpenSearch's clause limit. Hits the real index (no `Post.tag_match` stub).
  it "accepts a search with more free rating tokens than the OpenSearch clause limit" do
    tags = Array.new(1100) { |i| "rating:s#{i}" }.join(" ")
    expect(tags.bytesize).to be < ApplicationController::MAX_GET_PARAMETER_LENGTH

    post posts_path(format: :json), params: { _method: "GET", tags: tags }, headers: { "X-HTTP-Method-Override" => "GET" }
    expect(response).to have_http_status(:ok)
  end
end
