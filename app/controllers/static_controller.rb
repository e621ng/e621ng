# frozen_string_literal: true

class StaticController < ApplicationController
  def privacy
    @page = format_wiki_page("e621:privacy_policy")
  end

  def terms_of_service
    @page = format_wiki_page("e621:terms_of_service")
  end

  def contact
    @page = format_wiki_page("e621:contact")
  end

  def takedown
    @page = format_wiki_page("e621:takedown")
  end

  def avoid_posting
    @page = format_wiki_page("e621:avoid_posting_notice")
  end

  def not_found
    render "static/404", formats: [:html], status: 404
  end

  def error
  end

  def site_map
  end

  def home
    render layout: "blank"
  end

  def theme
  end

  def disable_mobile_mode
    if CurrentUser.is_member?
      user = CurrentUser.user
      user.disable_responsive_mode = !user.disable_responsive_mode
      user.save
    else
      if cookies[:nmm]
        cookies.delete(:nmm)
      else
        cookies.permanent[:nmm] = '1'
      end
    end
    redirect_back fallback_location: posts_path
  end

  def discord
    unless CurrentUser.can_discord?
      raise User::PrivilegeError.new("You must have an account for at least one week in order to join the Discord server.")
      return
    end
    if request.post?
      time = (Time.now + 5.minute).to_i
      secret = Danbooru.config.discord_secret
      # TODO: Proper HMAC
      hashed_values = Digest::SHA256.hexdigest("#{CurrentUser.name} #{CurrentUser.id} #{time} #{secret}")
      user_hash = "?user_id=#{CurrentUser.id}&username=#{CurrentUser.name}&time=#{time}&hash=#{hashed_values}"

      redirect_to(Danbooru.config.discord_site + user_hash, allow_other_host: true)
    end
  end

  private

  def format_wiki_page(name)
    wiki = WikiPage.find_by(title: name)
    return WikiPage.new(body: "Wiki page \"#{name}\" not found.") if wiki.blank?
    wiki
  end
end
