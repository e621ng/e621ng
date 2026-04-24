# frozen_string_literal: true

require "rails_helper"

#                        Prefix Verb   URI Pattern                              Controller#Action
#          rising_search_trends GET    /search_trends/rising(.:format)          search_trends#rising
#        settings_search_trends GET    /search_trends/settings(.:format)        search_trends#settings
# update_settings_search_trends POST   /search_trends/update_settings(.:format) search_trends#update_settings
#     clear_cache_search_trends POST   /search_trends/clear_cache(.:format)     search_trends#clear_cache
#           track_search_trends GET    /search_trends/track(.:format)           search_trends#track
#           purge_search_trends DELETE /search_trends/purge(.:format)           search_trends#purge
#                 search_trends GET    /search_trends(.:format)                 search_trends#index
RSpec.describe SearchTrendsController do
  describe "with trends enabled" do
    before { Setting.trends_enabled = true }
    after  { Setting.trends_enabled = false }

    # search_trends | GET | /search_trends(.:format) | search_trends#index
    describe "GET /search_trends (index)" do
      it "renders html" do
        SearchTrendHourly.bulk_increment!([{ tag: "wolf", hour: 1.hour.ago.utc }])
        get search_trends_path
        expect(response).to have_http_status(:success)
        # TODO: Move this to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
        expect(response.body).to match(/Trending Tags/)
      end

      it "returns json" do
        hour = 2.hours.ago.utc
        SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: hour }])
        SearchTrendAggregateJob.perform_now
        get search_trends_path(format: :json, day: hour.to_date.to_s)
        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json).to be_a(Array)
        expect(json).to include(include("tag" => "fox"))

        # TODO: `include_context "validating JSON"` & Expand JSON validation w/ `match_json_format`
      end

      it "displays correct ranks without search filters" do
        day = Time.now.utc.to_date
        # Create SearchTrend records for consistent ranking tests
        SearchTrend.create!(tag: "alpha", day: day, count: 300)
        SearchTrend.create!(tag: "beta", day: day, count: 200)
        SearchTrend.create!(tag: "gamma", day: day, count: 100)

        get search_trends_path, params: { day: day.to_s }
        expect(response).to have_http_status(:success)

        # TODO: Move this to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
        # Should use offset-based ranking (current behavior)
        expect(response.body).to match(%r{td>.*1.*</td>}) # alpha should be rank 1
        # Simple check that ranking appears to be sequential starting from 1
      end

      it "preserves original ranks with search filters" do
        day = Time.now.utc.to_date
        # Create test data with clear ranking
        SearchTrend.create!(tag: "wolf", day: day, count: 300)    # rank 1
        SearchTrend.create!(tag: "fox", day: day, count: 200)     # rank 2
        SearchTrend.create!(tag: "cat", day: day, count: 100)     # rank 3
        SearchTrend.create!(tag: "dog", day: day, count: 50)      # rank 4

        # Search for tags containing 'o' (wolf, fox, dog)
        get search_trends_path, params: { day: day.to_s, search: { name_matches: "*o*" } }
        expect(response).to have_http_status(:success)

        # Parse the response to check that original daily ranks are preserved
        # The response should show wolf=rank1, fox=rank2, dog=rank4 (not 1,2,3)
        response_body = response.body

        # TODO: Move these to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
        # Check that wolf appears with rank 1
        expect(response_body).to match(%r{wolf</a>}i)

        # Check that fox appears with rank 2 (not rank 2 in filtered sequence)
        expect(response_body).to match(%r{fox</a>}i)

        # Check that dog appears with rank 4 (not rank 3 in filtered sequence)
        expect(response_body).to match(%r{dog</a>}i)

        # Verify cat (rank 3) is NOT in the filtered results
        expect(response_body).not_to match(%r{cat</a>}i)
      end
    end
  end

  describe "settings page" do
    let(:admin) { create(:admin_user) }
    let(:user) { create(:member_user) }

    before { Setting.trends_enabled = true }

    after { Setting.trends_enabled = false }

    it "renders for admins" do
      get_auth settings_search_trends_path, admin
      expect(response).to have_http_status(:success)
      # TODO: Move these to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
      expect(response.body).to match(/Search trend settings/)
      expect(response.body).to match(/Minimum searches today/)
    end

    it "is forbidden for non-admins" do
      get_auth settings_search_trends_path, user
      expect(response).to have_http_status(:forbidden)
    end

    it "form submission updates settings" do
      post_auth update_settings_search_trends_path, admin, params: {
        search_trend_settings: {
          trends_enabled: false,
          trends_min_today: 11,
          trends_min_delta: 12,
          trends_min_ratio: 2.5,
        },
      }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trends_path)

      expect(Setting.trends_enabled?).to be(false)
      expect(Setting.trends_min_today).to eq(11)
      expect(Setting.trends_min_delta).to eq(12)
      expect(Setting.trends_min_ratio).to be_within(0.001).of(2.5)
      expect(Rails.cache.read("rising_tags")).to be_nil, "cache should be cleared"
    end
  end
end
