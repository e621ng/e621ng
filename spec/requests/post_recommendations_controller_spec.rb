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
      expect(body["model_version"]).to eq("opensearch")
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
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 6)
    end

    it "forwards a custom limit within range" do
      get artist_similar_path(post, format: :json), params: { limit: 10 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 10)
    end

    it "clamps limit below 1 up to 1" do
      get artist_similar_path(post, format: :json), params: { limit: 0 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1)
    end

    it "clamps a non-numeric limit string to 1" do
      get artist_similar_path(post, format: :json), params: { limit: "abc" }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 1)
    end

    it "clamps limit above 20 down to 20" do
      get artist_similar_path(post, format: :json), params: { limit: 999 }
      expect(PostSets::Recommended).to have_received(:new).with(post, limit: 20)
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

  # ---------------------------------------------------------------------------
  # GET /posts/:id/similar/lookup — thumbnail lookup by post IDs
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/similar/lookup" do
    # NOTE: The :id segment in the URL is required by the route but is not used
    # by the action — it reads params[:post_ids] instead. Any valid post is fine
    # as the path object.

    it "returns 200 with thumbnail attributes for provided post IDs" do
      get lookup_similar_path(post, format: :json), params: { post_ids: "#{post.id},#{recommended_post.id}" }
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck("id")
      expect(ids).to contain_exactly(post.id, recommended_post.id)
    end

    it "includes expected thumbnail keys in each result" do
      get lookup_similar_path(post, format: :json), params: { post_ids: post.id.to_s }
      entry = response.parsed_body.first
      expect(entry).to include("id", "tags", "rating", "file_ext", "uploader_id")
    end

    it "deduplicates repeated post IDs" do
      get lookup_similar_path(post, format: :json), params: { post_ids: "#{post.id},#{post.id},#{post.id}" }
      expect(response.parsed_body.length).to eq(1)
    end

    it "limits results to 20 when more than 20 IDs are provided" do
      uploader = create(:user)
      now = Time.current
      Post.insert_all(
        21.times.map do |i|
          { md5: Digest::MD5.hexdigest("limit_test_#{i}"), uploader_id: uploader.id,
            uploader_ip_addr: "127.0.0.1", source: "", rating: "s", file_ext: "jpg",
            file_size: 1000, image_width: 100, image_height: 100,
            created_at: now, updated_at: now, }
        end,
      )
      ids = Post.where(md5: 21.times.map { |i| Digest::MD5.hexdigest("limit_test_#{i}") }).pluck(:id).join(",")
      get lookup_similar_path(post, format: :json), params: { post_ids: ids }
      expect(response.parsed_body.length).to eq(20)
    end

    it "filters out non-numeric IDs" do
      get lookup_similar_path(post, format: :json), params: { post_ids: "abc,-1,0,1.5,#{post.id}" }
      ids = response.parsed_body.pluck("id")
      expect(ids).to eq([post.id])
    end

    it "returns an empty array when post_ids is blank" do
      get lookup_similar_path(post, format: :json), params: { post_ids: "" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns an empty array when post_ids param is absent" do
      get lookup_similar_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns an empty array when post IDs reference non-existent records" do
      get lookup_similar_path(post, format: :json), params: { post_ids: "99999999" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns 200 for anonymous (no auth required)" do
      get lookup_similar_path(post, format: :json), params: { post_ids: post.id.to_s }
      expect(response).to have_http_status(:ok)
    end
  end
end
