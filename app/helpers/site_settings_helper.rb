# frozen_string_literal: true

module SiteSettingsHelper
  def site_settings_json
    json_escape(site_settings_data.to_json).html_safe
  end

  private

  def site_settings_data
    {
      analytics: {
        enabled: Danbooru.config.enable_visitor_metrics? && Danbooru.config.analytics_client_id.present?,
        client_id: Danbooru.config.analytics_client_id,

        events: {
          recommendation: Setting.collect_recommendation_events?,
          search_trend: Setting.collect_search_trend_events?,
        },
      },
    }
  end
end
