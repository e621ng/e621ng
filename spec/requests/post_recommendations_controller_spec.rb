# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostRecommendationsController do
  include_context "as admin"

  let(:post)             { create(:post) }
  let(:recommended_post) { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /posts/:id/similar/artist — artist recommendations
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/similar/artist" do
    let(:recommended_double) { instance_double(PostSets::Recommended, post_ids: [recommended_post.id]) }

    before do
      allow(PostSets::Recommended).to receive(:new).and_return(recommended_double)
    end

    it "returns 200 with the expected JSON structure" do
      get artist_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["post_id"]).to eq(post.id)
      expect(body["model_version"]).to eq("os.artist")
      expect(body["results"]).to be_an(Array)
      expect(body["post_data"]).to be_an(Array)
    end

    it "does not include the order key in the response" do
      get artist_similar_path(post, format: :json)
      expect(response.parsed_body).not_to have_key("order")
    end

    it "populates post_data with thumbnail attributes for recommended posts" do
      get artist_similar_path(post, format: :json)
      post_data = response.parsed_body["post_data"]
      expect(post_data.length).to eq(1)
      entry = post_data.first
      expect(entry["id"]).to eq(recommended_post.id)
      expect(entry).to include("tags", "rating", "file_ext", "uploader_id")
    end

    it "defaults limit to 6 when not provided" do
      get artist_similar_path(post, format: :json)
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 6, mode: :artist)
    end

    it "forwards a custom limit within range" do
      get artist_similar_path(post, format: :json), params: { limit: 10 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 10, mode: :artist)
    end

    it "clamps limit below 1 up to 1" do
      get artist_similar_path(post, format: :json), params: { limit: 0 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1, mode: :artist)
    end

    it "clamps a non-numeric limit string to 1" do
      get artist_similar_path(post, format: :json), params: { limit: "abc" }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1, mode: :artist)
    end

    it "clamps limit above 20 down to 20" do
      get artist_similar_path(post, format: :json), params: { limit: 999 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 20, mode: :artist)
    end

    it "returns empty results and post_data when post is not visible" do
      allow(Security::Lockdown).to receive(:post_visible?).and_return(false)
      get artist_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["results"]).to eq([])
      expect(body["post_data"]).to eq([])
      expect(PostSets::Recommended).not_to have_received(:new)
    end

    it "returns empty results and post_data when there are no recommendations" do
      allow(recommended_double).to receive(:post_ids).and_return([])
      get artist_similar_path(post, format: :json)
      body = response.parsed_body
      expect(body["results"]).to eq([])
      expect(body["post_data"]).to eq([])
    end

    it "returns 404 for a non-existent post" do
      get "/posts/0/similar/artist.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id/similar/tags — tag-based recommendations
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/similar/tags" do
    let(:recommended_double) { instance_double(PostSets::Recommended, post_ids: [recommended_post.id]) }

    before do
      allow(PostSets::Recommended).to receive(:new).and_return(recommended_double)
    end

    it "returns 200 with the expected JSON structure" do
      get tags_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["post_id"]).to eq(post.id)
      expect(body["model_version"]).to eq("os.tags")
      expect(body["results"]).to be_an(Array)
      expect(body["post_data"]).to be_an(Array)
    end

    it "does not include the order key in the response" do
      get tags_similar_path(post, format: :json)
      expect(response.parsed_body).not_to have_key("order")
    end

    it "populates post_data with thumbnail attributes for recommended posts" do
      get tags_similar_path(post, format: :json)
      post_data = response.parsed_body["post_data"]
      expect(post_data.length).to eq(1)
      entry = post_data.first
      expect(entry["id"]).to eq(recommended_post.id)
      expect(entry).to include("tags", "rating", "file_ext", "uploader_id")
    end

    it "defaults limit to 6 when not provided" do
      get tags_similar_path(post, format: :json)
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 6, mode: :tags)
    end

    it "forwards a custom limit within range" do
      get tags_similar_path(post, format: :json), params: { limit: 10 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 10, mode: :tags)
    end

    it "clamps limit below 1 up to 1" do
      get tags_similar_path(post, format: :json), params: { limit: 0 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1, mode: :tags)
    end

    it "clamps a non-numeric limit string to 1" do
      get tags_similar_path(post, format: :json), params: { limit: "abc" }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1, mode: :tags)
    end

    it "clamps limit above 20 down to 20" do
      get tags_similar_path(post, format: :json), params: { limit: 999 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 20, mode: :tags)
    end

    it "returns empty results and post_data when post is not visible" do
      allow(Security::Lockdown).to receive(:post_visible?).and_return(false)
      get tags_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["results"]).to eq([])
      expect(body["post_data"]).to eq([])
      expect(PostSets::Recommended).not_to have_received(:new)
    end

    it "returns empty results and post_data when there are no recommendations" do
      allow(recommended_double).to receive(:post_ids).and_return([])
      get tags_similar_path(post, format: :json)
      body = response.parsed_body
      expect(body["results"]).to eq([])
      expect(body["post_data"]).to eq([])
    end

    it "returns 404 for a non-existent post" do
      get "/posts/0/similar/tags.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id/similar/remote — remote recommendations (not implemented)
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/similar/remote" do
    it "returns 200 with the expected JSON structure" do
      get remote_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["post_id"]).to eq(post.id)
      expect(body["model_version"]).to eq("not_implemented")
      expect(body["results"]).to eq([])
    end

    it "does not include a post_data key in the response" do
      get remote_similar_path(post, format: :json)
      expect(response.parsed_body).not_to have_key("post_data")
    end

    it "returns the same structure when the post is not visible" do
      allow(Security::Lockdown).to receive(:post_visible?).and_return(false)
      get remote_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["post_id"]).to eq(post.id)
      expect(body["model_version"]).to eq("not_implemented")
      expect(body["results"]).to eq([])
    end

    it "returns 404 for a non-existent post" do
      get "/posts/0/similar/remote.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
