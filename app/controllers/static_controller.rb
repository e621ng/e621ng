# frozen_string_literal: true

class StaticController < ApplicationController
  def privacy
    @page_name = "e621:privacy_policy"
    @page = format_wiki_page(@page_name)
  end

  def code_of_conduct
    @page_name = "e621:rules"
    @page = format_wiki_page(@page_name)
  end

  def contact
    @page_name = "e621:contact"
    @page = format_wiki_page(@page_name)
  end

  def takedown
    @page_name = "e621:takedown"
    @page = format_wiki_page(@page_name)
  end

  def avoid_posting
    @page_name = "e621:avoid_posting_notice"
    @page = format_wiki_page(@page_name)
  end

  def furid
  end

  def not_found
    render "static/404", formats: [:html], status: 404
  end

  def error
  end

  def site_map
    @sections = SiteMap.sections_for(CurrentUser.user)
  end

  def robots
    render "static/robots", formats: [:text], layout: false
  end

  def home
    @mascot_id = cookies[:mascot].to_i
    mascot_list = Mascot.active_for_browser
    selected_mascot = @mascot_id > 0 ? mascot_list[@mascot_id] : nil
    selected_mascot ||= mascot_list[mascot_list.keys.sample]

    if selected_mascot.present?
      @mascot_id = selected_mascot["id"]
      @mascot_background_url = selected_mascot["background_url"]
      @mascot_artist_name = selected_mascot["artist_name"]
      @mascot_artist_url = selected_mascot["artist_url"]

      @extra_body_args = {
        style: [
          "--bg-image: url('#{@mascot_background_url}')",
          "--bg-color: #{selected_mascot['background_color']}",
          "--fg-color: #{selected_mascot['foreground_color']}",
        ].join(";"),
        layered: ("true" if selected_mascot["is_layered"]),
      }
    end

    render layout: "blank", formats: [:html]
  end

  def theme
  end

  def disable_mobile_mode
    if CurrentUser.user.is_logged_out?
      if cookies[:nmm]
        cookies.delete(:nmm)
      else
        cookies.permanent[:nmm] = "1"
      end
    else
      user = CurrentUser.user
      user.disable_responsive_mode = !user.disable_responsive_mode
      user.save
    end
    redirect_back fallback_location: posts_path
  end

  def discord
    if request.post?
      raise User::PrivilegeError, "You must have an account for at least one week in order to join the Discord server." unless CurrentUser.can_discord?

      time = (Time.now + 5.minutes).to_i
      secret = Danbooru.config.discord_secret
      # TODO: Proper HMAC
      hashed_values = Digest::SHA256.hexdigest("#{CurrentUser.name} #{CurrentUser.id} #{time} #{secret}")
      user_hash = "?user_id=#{CurrentUser.id}&username=#{CurrentUser.name}&time=#{time}&hash=#{hashed_values}"

      redirect_to(Danbooru.config.discord_site + user_hash, allow_other_host: true)
    else
      @page_name = "e621:discord"
      @page = format_wiki_page(@page_name)
    end
  end

  private

  def format_wiki_page(name)
    wiki = WikiPage.titled(name)
    return WikiPage.new(body: "Wiki page \"#{name}\" not found.") if wiki.blank?
    wiki
  end
end
