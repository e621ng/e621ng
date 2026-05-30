# frozen_string_literal: true

require "rails_helper"

RSpec.describe DbExportsController do
  include_context "as admin"

  let(:member) { create(:user) }

  before do
    DbExport.create!(name: "posts", file_size: 2048)
    DbExport.create!(name: "tags", file_size: 512)
  end

  describe "GET /db_exports" do
    it "renders for anonymous users" do
      get db_exports_path
      expect(response).to have_http_status(:ok)
    end

    it "lists the available exports" do
      get db_exports_path
      expect(response.body).to include("posts")
      expect(response.body).to include("tags")
    end

    it "returns 404 when exports are disabled" do
      allow(Danbooru.config.custom_configuration).to receive(:db_export_enabled?).and_return(false)
      get db_exports_path
      expect(response).to have_http_status(:not_found)
    end

    it "renders a JSON array with export metadata" do
      get db_exports_path(format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to be_an(Array)
      entry = body.find { |export| export["name"] == "posts" }
      expect(entry).to include("file_name" => "posts.csv.gz", "file_size" => 2048)
      expect(entry["url"]).to be_present
    end
  end

  describe "GET /db_exports/favorites" do
    it "rejects anonymous users" do
      get favorites_db_exports_path
      expect(response).to have_http_status(:found)
    end

    it "streams the favorites of a logged-in user as CSV" do
      post_record = create(:post)
      FavoriteManager.add!(user: member, post: post_record)

      sign_in_as(member)
      get favorites_db_exports_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include(post_record.id.to_s)
    end
  end

  describe "GET /db_exports/votes" do
    it "rejects anonymous users" do
      get votes_db_exports_path
      expect(response).to have_http_status(:found)
    end

    it "streams the post votes of a logged-in user as CSV" do
      post_record = create(:post)
      create(:post_vote, user: member, post: post_record, score: 1)

      sign_in_as(member)
      get votes_db_exports_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include(post_record.id.to_s)
    end
  end
end
