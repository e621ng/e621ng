# frozen_string_literal: true

require "rails_helper"

RSpec.describe SiteSettingsHelper do
  # Decodes the base64 JSON blobs the helper emits into script tags, mirroring
  # what the front-end (Settings.ts / CurrentUser.ts / CurrentPost.ts) does.
  def decode(base64)
    JSON.parse(Base64.strict_decode64(base64))
  end

  before do
    CurrentUser.user    = create(:user)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  describe "#site_settings_base64" do
    subject(:settings) { decode(helper.site_settings_base64) }

    it "round-trips to a parseable JSON structure with the expected keys" do
      expect(settings.keys).to match_array(%w[Analytics Autocomplete Posts])
    end

    context "when visitor metrics are enabled and a client id is set" do
      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(enable_visitor_metrics?: true, analytics_client_id: "G-ABC123")
      end

      it "enables analytics and exposes the client id" do
        expect(settings["Analytics"]).to include("enabled" => true, "client_id" => "G-ABC123")
      end
    end

    context "when visitor metrics are disabled" do
      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(enable_visitor_metrics?: false, analytics_client_id: "G-ABC123")
      end

      it "disables analytics and withholds the client id" do
        expect(settings["Analytics"]).to include("enabled" => false, "client_id" => nil)
      end
    end

    context "when a client id is missing" do
      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(enable_visitor_metrics?: true, analytics_client_id: nil)
      end

      it "does not enable analytics" do
        expect(settings["Analytics"]).to include("enabled" => false, "client_id" => nil)
      end
    end

    it "reflects the configured analytics event flags" do
      allow(Danbooru.config.custom_configuration).to receive(:visitor_metrics_events)
        .and_return(recommendation: true, search_trend: false)

      expect(settings["Analytics"]["events"]).to eq("recommendation" => true, "search_trend" => false)
    end

    it "defaults missing analytics event flags to false" do
      allow(Danbooru.config.custom_configuration).to receive(:visitor_metrics_events).and_return({})

      expect(settings["Analytics"]["events"]).to eq("recommendation" => false, "search_trend" => false)
    end

    it "exposes the autocomplete blacklist" do
      allow(Danbooru.config.custom_configuration).to receive(:default_autocomplete_blacklist).and_return(%w[foo bar])

      expect(settings["Autocomplete"]["blacklist"]).to eq(%w[foo bar])
    end

    it "reflects the webp preview flag" do
      allow(Danbooru.config.custom_configuration).to receive(:webp_previews_enabled?).and_return(false)

      expect(settings["Posts"]["webp_enabled"]).to be false
    end
  end

  describe "#site_user_base64" do
    subject(:user_data) { decode(helper.site_user_base64) }

    # The blueprint's own contract is covered by user_include_blueprint_spec; here
    # we only assert the base64 wrapper round-trips to the current user's payload.
    it "round-trips to the current user's blueprint payload" do
      expect(user_data).to include("id" => CurrentUser.user.id, "name" => CurrentUser.user.name)
    end
  end

  describe "#post_show_base64" do
    subject(:post_data) { decode(helper.post_show_base64(post)) }

    let(:post) { create(:post) }

    it "round-trips to the post's blueprint payload" do
      expect(post_data).to include("id" => post.id)
    end

    it "merges in the initial_size from the presenter" do
      # #presenter is memoized on the post, so stubbing the returned instance is
      # enough — the helper reads back the same object.
      allow(post.presenter).to receive(:default_image_size).and_return("original")

      expect(post_data["initial_size"]).to eq("original")
    end
  end
end
