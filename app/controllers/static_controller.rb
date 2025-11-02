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

  def subscribestar
    @page_name = "e621:subscribestar"
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
    @sections = build_site_map_sections
    @section_groups = site_map_section_groups
    @section_titles = site_map_section_titles
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
    elsif cookies[:nmm]
      cookies.delete(:nmm)
    else
      cookies.permanent[:nmm] = "1"
    end
    redirect_back fallback_location: posts_path
  end

  def discord
    raise User::PrivilegeError, "You must have an account for at least one week in order to join the Discord server." unless CurrentUser.can_discord?

    if request.post?
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

  def site_map_section_groups
    [
      %i[posts post_events tools],
      %i[artists tags notes pools sets],
      %i[comments forum wiki blips],
      %i[users staff admin],
    ]
  end

  def site_map_section_titles
    {
      posts: "Posts",
      post_events: "Post Events",
      tools: "Tools",
      artists: "Artists",
      tags: "Tags",
      notes: "Notes",
      pools: "Pools",
      sets: "Sets",
      comments: "Comments",
      forum: "Forum",
      wiki: "Wiki",
      blips: "Blips",
      users: "Users",
      staff: "Staff",
      admin: "Admin",
    }
  end

  def build_site_map_sections
    sections = site_map_section_titles.each_key.index_with { |_key| [] }
    h = helpers

    sections[:posts] << h.link_to("Listing", posts_path)
    sections[:posts] << h.link_to("Upload", new_upload_path)
    sections[:posts] << h.link_to("Popular", popular_index_path)
    sections[:posts] << h.link_to("Changes", post_versions_path)
    sections[:posts] << h.link_to("Similar Images Search", iqdb_queries_path)
    sections[:posts] << h.link_to("Deleted Index", deleted_posts_path)

    sections[:post_events] << h.link_to("Listing", post_events_path)
    sections[:post_events] << h.link_to("Tag Changes", post_versions_path)
    sections[:post_events] << h.link_to("Approvals", post_approvals_path)
    sections[:post_events] << h.link_to("Flags", post_flags_path)
    sections[:post_events] << h.link_to("Replacements", post_replacements_path)

    sections[:tools] << h.link_to("News Updates", news_updates_path)
    sections[:tools] << h.link_to("Mascots", mascots_path)
    sections[:tools] << h.link_to("FurID", furid_path)
    sections[:tools] << h.link_to("Source Code", Danbooru.config.source_code_url)
    sections[:tools] << h.link_to("Keyboard Shortcuts", keyboard_shortcuts_path)
    sections[:tools] << h.link_to("API Documentation", help_page_path(id: "api"))
    sections[:tools] << h.link_to("Stats", stats_path)
    sections[:tools] << h.link_to("Terms of Use", terms_of_use_path)
    sections[:tools] << h.link_to("Privacy Policy", privacy_policy_path)
    sections[:tools] << h.link_to("Code of Conduct", code_of_conduct_path)

    sections[:artists] << h.link_to("Listing", artists_path)
    sections[:artists] << h.link_to("URLs", artist_urls_path)
    sections[:artists] << h.link_to("Avoid Posting Entries", avoid_postings_path)
    sections[:artists] << h.link_to("Avoid Posting List", avoid_posting_static_path)
    sections[:artists] << h.link_to("Changes", artist_versions_path)

    sections[:tags] << h.link_to("Listing", tags_path)
    sections[:tags] << h.link_to("Type Changes", tag_type_versions_path)
    sections[:tags] << h.link_to("MetaSearch", meta_searches_tags_path)
    sections[:tags] << h.link_to("Aliases", tag_aliases_path)
    sections[:tags] << h.link_to("Implications", tag_implications_path)
    sections[:tags] << h.link_to("Bulk Update Requests", bulk_update_requests_path)
    sections[:tags] << h.link_to("Cheat sheet", help_page_path(id: "cheatsheet"))

    sections[:notes] << h.link_to("Listing", notes_path)
    sections[:notes] << h.link_to("Changes", note_versions_path)

    sections[:pools] << h.link_to("Listing", gallery_pools_path)
    sections[:pools] << h.link_to("Changes", pool_versions_path)

    sections[:wiki] << h.link_to("Listing", wiki_pages_path)
    sections[:wiki] << h.link_to("Changes", wiki_page_versions_path)

    sections[:sets] << h.link_to("Listing", post_sets_path)
    sections[:comments] << h.link_to("Listing", comments_path)
    sections[:forum] << h.link_to("Listing", forum_topics_path)
    sections[:blips] << h.link_to("Listing", blips_path)

    sections[:users] << h.link_to("Listing", users_path)
    sections[:users] << h.link_to("Bans", bans_path)
    sections[:users] << h.link_to("Feedback", user_feedbacks_path)

    sections[:staff] << h.link_to("Upload Whitelist", upload_whitelists_path)
    sections[:staff] << h.link_to("Mod Actions", mod_actions_path)
    sections[:staff] << h.link_to("Takedowns", takedowns_path)
    sections[:staff] << h.link_to("Tickets", tickets_path)

    if Danbooru.config.subscribestar_url.present?
      sections[:tools] << h.link_to("Subscribestar", Danbooru.config.subscribestar_url)
    end

    if Danbooru.config.db_export_path.present?
      sections[:tools] << h.link_to("DB Export", Danbooru.config.db_export_path)
    end

    sections[:tools] << h.link_to("Discord", discord_post_path) if CurrentUser.can_discord?
    sections[:users] << h.link_to("Signup", new_user_path) if CurrentUser.is_anonymous?

    unless CurrentUser.is_anonymous?
      sections[:users] << h.link_to("User Home", home_users_path)
      sections[:users] << h.link_to("Profile", user_path(CurrentUser.user))
      sections[:users] << h.link_to("Settings", settings_users_path)
      sections[:users] << h.link_to("Refresh counts", new_maintenance_user_count_fixes_path)
    end

    if CurrentUser.is_staff?
      sections[:staff] << h.link_to("Mod Dashboard", moderator_dashboard_path)
      sections[:posts] << h.link_to("Upload Listing", uploads_path)
    end

    sections[:post_events] << h.link_to("Disapprovals", moderator_post_disapprovals_path) if CurrentUser.can_approve_posts?

    if CurrentUser.is_moderator?
      sections[:staff] << h.link_to("Edit Histories", edit_histories_path)
      sections[:staff] << h.link_to("Post Votes", index_post_votes_path)
      sections[:users] << h.link_to("User Name Changes", user_name_change_requests_path)
    end

    if CurrentUser.is_admin?
      sections[:admin] << h.link_to("Admin Dashboard", admin_dashboard_path)
      sections[:admin] << h.link_to("Forum Categories", forum_categories_path)
      sections[:admin] << h.link_to("IP Addresses", moderator_ip_addrs_path)
      sections[:admin] << h.link_to("IP Bans", ip_bans_path)
      sections[:admin] << h.link_to("Post Report Reasons", post_report_reasons_path)
      sections[:admin] << h.link_to("Email Blacklist", email_blacklists_path)
      sections[:admin] << h.link_to("Destroyed Posts", admin_destroyed_posts_path)
      sections[:admin] << h.link_to("Exceptions", admin_exceptions_path)
      sections[:admin] << h.link_to("Stuck DNP tags", new_admin_stuck_dnp_path)
      sections[:admin] << h.link_to("Security", security_root_path)
      sections[:admin] << h.link_to("Alt list", alt_list_admin_users_path)
      sections[:admin] << h.link_to("SideKiq", sidekiq_path)
    end

    sections[:admin] << h.link_to("Reowner", new_admin_reowner_path) if CurrentUser.is_bd_staff?

    sections[:users] << h.link_to("Staff Notes", staff_notes_path) if CurrentUser.can_view_staff_notes?

    sections[:posts] << h.link_to("Help", help_page_path(id: "posts"))
    sections[:artists] << h.link_to("Help", help_page_path(id: "artists"))
    sections[:tags] << h.link_to("Help", help_page_path(id: "tags"))
    sections[:notes] << h.link_to("Help", help_page_path(id: "notes"))
    sections[:pools] << h.link_to("Help", help_page_path(id: "pools"))
    sections[:sets] << h.link_to("Help", help_page_path(id: "sets"))
    sections[:comments] << h.link_to("Help", help_page_path(id: "comments"))
    sections[:forum] << h.link_to("Help", help_page_path(id: "forum"))
    sections[:wiki] << h.link_to("Help", help_page_path(id: "wiki"))
    sections[:blips] << h.link_to("Help", help_page_path(id: "blips"))
    sections[:users] << h.link_to("Help", help_page_path(id: "accounts"))
    sections[:tools] << h.link_to("Help Index", help_pages_path)

    sections
  end

  def format_wiki_page(name)
    wiki = WikiPage.titled(name)
    return WikiPage.new(body: "Wiki page \"#{name}\" not found.") if wiki.blank?
    wiki
  end
end
