# frozen_string_literal: true

# A stubbed e926 profile (doc 38). Requests select it with the
# X-E6-Site header or a Host of e926.net; other code uses CurrentSite.with("e926").
RSpec.shared_context "with e926 site profile" do
  let(:e926_ads_config) do
    {
      revive: { domain: "rv.e621.net", id: "test" },
      areas: {
        top: { desktop: { zone: 3 }, mobile: { zone: 37 } },
        bottom: { desktop: { zone: 3 }, mobile: { zone: 37 } },
      },
    }
  end

  let(:e926_profile) do
    {
      hosts: %w[e926.net www.e926.net],
      safe_mode: true,
      overrides: {
        app_name: "e926",
        hostname: "e926.net",
        domain: "e926.net",
        description: "e926",
        storage_base_url: "https://static1.e926.net/",
        ads_config: e926_ads_config,
        analytics_client_id: "e926-client",
      },
    }
  end

  before do
    allow(Danbooru.config.custom_configuration).to receive(:site_profiles).and_return({ "e926" => e926_profile })
  end
end
