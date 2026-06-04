# frozen_string_literal: true

require "rails_helper"

RSpec.describe DbExportsController do
  before do
    allow(Danbooru.config.custom_configuration).to receive(:db_export_enabled?).and_return(true)
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
end
