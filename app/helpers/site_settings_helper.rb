# frozen_string_literal: true

module SiteSettingsHelper
  # Base64-encoded JSON blob containing site settings for use in JavaScript.
  def site_settings_base64
    Base64.strict_encode64(site_settings_data.to_json)
  end

  private

  def site_settings_data
    analytics_enabled = Danbooru.config.enable_visitor_metrics? && Danbooru.config.analytics_client_id.present?

    {
      Analytics: {
        enabled: analytics_enabled,
        client_id: analytics_enabled ? Danbooru.config.analytics_client_id : nil,

        events: {
          recommendation: Danbooru.config.visitor_metrics_events[:recommendation] || false,
          search_trend: Danbooru.config.visitor_metrics_events[:search_trend] || false,
        },
      },
      Posts: {
        webp_enabled: Danbooru.config.webp_previews_enabled?,
      },
      Recommender: {
        remote: Danbooru.config.recommender_enabled? && CurrentUser.user.is_staff?, # Gradual rollout
      },
    }
  end
end
