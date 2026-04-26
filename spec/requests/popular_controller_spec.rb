# frozen_string_literal: true

require "rails_helper"

RSpec.describe PopularController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  describe "GET /popular" do
    context "with no parameters" do
      it "returns 200 for anonymous" do
        get popular_index_path
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 and a posts key in JSON" do
        get popular_index_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key("posts")
        expect(response.parsed_body["posts"]).to be_an(Array)
      end

      it "includes a post created today in the JSON response" do
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do
          post = create(:post)
          get popular_index_path(format: :json)
          ids = response.parsed_body["posts"].pluck("id")
          expect(ids).to include(post.id)
        end
      end
    end

    context "with scale=week" do
      it "returns 200" do
        get popular_index_path(scale: "week")
        expect(response).to have_http_status(:ok)
      end

      it "includes a post created earlier in the same week" do
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do # Saturday
          post = create(:post)
          post.update_columns(created_at: Time.zone.parse("2024-06-10 12:00:00")) # Monday same week
          get popular_index_path(format: :json, scale: "week", date: "2024-06-15")
          ids = response.parsed_body["posts"].pluck("id")
          expect(ids).to include(post.id)
        end
      end

      it "excludes a post created in a different week" do
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do
          post = create(:post)
          post.update_columns(created_at: Time.zone.parse("2024-06-01 12:00:00")) # prior week
          get popular_index_path(format: :json, scale: "week", date: "2024-06-15")
          ids = response.parsed_body["posts"].pluck("id")
          expect(ids).not_to include(post.id)
        end
      end
    end

    context "with scale=month" do
      it "returns 200" do
        get popular_index_path(scale: "month")
        expect(response).to have_http_status(:ok)
      end

      it "includes a post created earlier in the same month" do
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do
          post = create(:post)
          post.update_columns(created_at: Time.zone.parse("2024-06-01 12:00:00"))
          get popular_index_path(format: :json, scale: "month", date: "2024-06-15")
          ids = response.parsed_body["posts"].pluck("id")
          expect(ids).to include(post.id)
        end
      end

      it "excludes a post created in a different month" do
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do
          post = create(:post)
          post.update_columns(created_at: Time.zone.parse("2024-05-31 12:00:00"))
          get popular_index_path(format: :json, scale: "month", date: "2024-06-15")
          ids = response.parsed_body["posts"].pluck("id")
          expect(ids).not_to include(post.id)
        end
      end
    end

    context "with a valid date param" do
      it "returns 200" do
        get popular_index_path(date: "2024-01-15")
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid date param" do
      it "returns 422 for HTML" do
        get popular_index_path(date: "not-a-date")
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 422 for JSON" do
        get popular_index_path(format: :json, date: "not-a-date")
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
