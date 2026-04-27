# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatsController do
  let(:redis_double) { instance_spy(Redis) }

  # Minimum payload required for the view to render without errors.
  # The percentage_table partial compares @stats[total_key] > 0 for all total
  # keys — if those keys are absent (nil), NoMethodError is raised. Setting
  # them to 0 satisfies the guard without implying real data.
  # "started" is required because the view calls DateTime.parse(@stats["started"]).
  let(:minimal_stats) do
    {
      "started"        => "2007-03-15T00:00:00Z",
      "total_posts"    => 0,
      "existing_posts" => 0,
      "total_users"    => 0,
      "total_comments" => 0,
      "total_blips"    => 0,
      "total_tags"     => 0,
      "total_sets"     => 0,
    }
  end

  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
    allow(Cache).to receive(:redis).and_return(redis_double)
    allow(redis_double).to receive(:get).with("e6stats").and_return(minimal_stats.to_json)
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  describe "GET /stats" do
    it "returns 406 when JSON format is requested" do
      get stats_path(format: :json)
      expect(response).to have_http_status(:not_acceptable)
    end

    # FIXME: When Redis returns nil, @stats is {} and the view raises in two
    # places: (1) DateTime.parse(@stats["started"]) → TypeError on nil, and
    # (2) @stats[total_key] > 0 → NoMethodError on nil for every percentage
    # column. Fix requires guarding both call sites in the view.
    # it "returns 200 when there are no cached stats" do
    #   allow(redis_double).to receive(:get).with("e6stats").and_return(nil)
    #   get stats_path
    #   expect(response).to have_http_status(:ok)
    # end

    context "when the e6stats key holds a minimal valid payload" do
      it "returns 200 for an anonymous visitor" do
        get stats_path
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a signed-in member" do
        sign_in_as create(:user)
        get stats_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the e6stats key holds a populated payload" do
      let(:stats_payload) do
        {
          "started"        => "2007-03-15T00:00:00Z",
          "total_posts"    => 1_234_567,
          "existing_posts" => 1_000_000,
          "total_users"    => 98_765,
          "total_comments" => 0,
          "total_blips"    => 0,
          "total_tags"     => 0,
          "total_sets"     => 0,
        }.to_json
      end

      before do
        allow(redis_double).to receive(:get).with("e6stats").and_return(stats_payload)
      end

      it "returns 200" do
        get stats_path
        expect(response).to have_http_status(:ok)
      end

      it "passes the parsed stats hash to the view" do
        get stats_path
        expect(response.body).to include("1,234,567")
      end
    end
  end
end
