# frozen_string_literal: true

module RegionNoticeHelper
  def show_region_notice?
    # Manual trigger for testing
    return true if params[:region_notice].to_s.truthy?
    return false if cookies[:hide_region_notice] == "1"
    # Avoid stacking on top of the TOS modal
    return false if !content_for?(:skip_tos_warning) && cookies[:tos_accepted].to_i != Setting.tos_version

    Danbooru.config.region_notice_countries.include?(request.headers["CF-IPCountry"].to_s.upcase)
  end
end
