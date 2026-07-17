# frozen_string_literal: true

module SiteSettingsHelper
  # Base64-encoded JSON blob containing site settings for use in JavaScript.
  def site_settings_base64
    Base64.strict_encode64(site_settings_data.to_json)
  end

  def site_user_base64
    Base64.strict_encode64(site_user_data.to_json)
  end

  # Page-scoped post payload for the posts#show media/resize system.
  def post_show_base64(post)
    Base64.strict_encode64(
      PostBlueprint.render_as_hash(post, view: :extended)
        .merge({ initial_size: post.presenter.default_image_size(CurrentUser.user) })
        .to_json,
    )
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
      Autocomplete: {
        blacklist: Danbooru.config.default_autocomplete_blacklist,
      },
      Posts: {
        webp_enabled: Danbooru.config.webp_previews_enabled?,
      },
    }
  end

  def site_user_data
    UserIncludeBlueprint.render_as_hash(CurrentUser.user)
  end
end
