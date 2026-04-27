# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendHourliesController do
  let(:admin) { create(:admin_user) }
  let(:user)  { create(:member_user) }

  describe "GET /search_trend_hourlies" do
    context "as anonymous" do
      it "redirects to the login page" do
        get search_trend_hourlies_path
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(new_session_path(url: search_trend_hourlies_path))
      end
    end

    context "as a member" do
      it "is forbidden" do
        get_auth search_trend_hourlies_path, user
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      it "renders successfully" do
        get_auth search_trend_hourlies_path, admin
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON array" do
        create(:search_trend_hourly)
        get_auth search_trend_hourlies_path(format: :json), admin
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      it "returns only the expected JSON fields" do
        create(:search_trend_hourly)
        get_auth search_trend_hourlies_path(format: :json), admin
        expect(response.parsed_body.first.keys).to contain_exactly("tag", "count", "hour", "processed")
      end

      context "with a valid hour param" do
        it "returns only entries for the specified past hour" do
          past_hour = 2.hours.ago.utc.beginning_of_hour
          earlier_hour = 3.hours.ago.utc.beginning_of_hour
          target = create(:search_trend_hourly, hour: past_hour)
          other  = create(:search_trend_hourly, hour: earlier_hour)

          get_auth search_trend_hourlies_path(format: :json, hour: past_hour.iso8601), admin

          tags = response.parsed_body.pluck("tag")
          expect(tags).to include(target.tag)
          expect(tags).not_to include(other.tag)
        end
      end

      context "with an invalid hour param" do
        it "falls back to the current hour" do
          current = create(:search_trend_hourly)
          past    = create(:search_trend_hourly, hour: 2.hours.ago.utc.beginning_of_hour)

          get_auth search_trend_hourlies_path(format: :json, hour: "not-a-time"), admin

          tags = response.parsed_body.pluck("tag")
          expect(tags).to include(current.tag)
          expect(tags).not_to include(past.tag)
        end
      end

      context "with a name_matches search param" do
        it "filters results by exact tag name" do
          wolf = create(:search_trend_hourly, tag: "wolf")
          fox  = create(:search_trend_hourly, tag: "fox")

          get_auth search_trend_hourlies_path(format: :json, search: { name_matches: "wolf" }), admin

          tags = response.parsed_body.pluck("tag")
          expect(tags).to include(wolf.tag)
          expect(tags).not_to include(fox.tag)
        end

        it "supports wildcard matching" do
          create(:search_trend_hourly, tag: "blue_wolf")
          create(:search_trend_hourly, tag: "red_fox")

          get_auth search_trend_hourlies_path(format: :json, search: { name_matches: "*wolf*" }), admin

          tags = response.parsed_body.pluck("tag")
          expect(tags).to include("blue_wolf")
          expect(tags).not_to include("red_fox")
        end
      end
    end
  end
end
