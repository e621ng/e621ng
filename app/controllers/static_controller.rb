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

  def site_map_layout
    [
      [
        { key: :posts, title: "Posts" },
        { key: :post_events, title: "Post Events" },
        { key: :tools, title: "Tools" },
      ],
      [
        { key: :artists, title: "Artists" },
        { key: :tags, title: "Tags" },
        { key: :notes, title: "Notes" },
        { key: :pools, title: "Pools" },
        { key: :sets, title: "Sets" },
      ],
      [
        { key: :comments, title: "Comments" },
        { key: :forum, title: "Forum" },
        { key: :wiki, title: "Wiki" },
        { key: :blips, title: "Blips" },
      ],
      [
        { key: :users, title: "Users" },
        { key: :staff, title: "Staff" },
        { key: :admin, title: "Admin" },
      ],
    ]
  end

  def build_site_map_sections
    sections = site_map_layout.map do |group|
      # Initialize each section with an empty links array
      group.map do |config|
        config.merge(links: [])
      end
    end

    lookup = sections.flatten.index_by { |section| section[:key] }
    add_link = ->(section, label, path) { lookup[section][:links] << { label: label, path: path } }

    add_link[:posts, "Listing", posts_path]
    add_link[:posts, "Upload", new_upload_path]
    add_link[:posts, "Popular", popular_index_path]
    add_link[:posts, "Changes", post_versions_path]
    add_link[:posts, "Similar Images Search", iqdb_queries_path]
    add_link[:posts, "Deleted Index", deleted_posts_path]

    add_link[:post_events, "Listing", post_events_path]
    add_link[:post_events, "Tag Changes", post_versions_path]
    add_link[:post_events, "Approvals", post_approvals_path]
    add_link[:post_events, "Flags", post_flags_path]
    add_link[:post_events, "Replacements", post_replacements_path]

    add_link[:tools, "News Updates", news_updates_path]
    add_link[:tools, "Mascots", mascots_path]
    add_link[:tools, "FurID", furid_path]
    add_link[:tools, "Source Code", Danbooru.config.source_code_url]
    add_link[:tools, "Keyboard Shortcuts", keyboard_shortcuts_path]
    add_link[:tools, "API Documentation", help_page_path(id: "api")]
    add_link[:tools, "Stats", stats_path]
    add_link[:tools, "Terms of Use", terms_of_use_path]
    add_link[:tools, "Privacy Policy", privacy_policy_path]
    add_link[:tools, "Code of Conduct", code_of_conduct_path]

    add_link[:artists, "Listing", artists_path]
    add_link[:artists, "URLs", artist_urls_path]
    add_link[:artists, "Avoid Posting Entries", avoid_postings_path]
    add_link[:artists, "Avoid Posting List", avoid_posting_static_path]
    add_link[:artists, "Changes", artist_versions_path]

    add_link[:tags, "Listing", tags_path]
    add_link[:tags, "Type Changes", tag_type_versions_path]
    add_link[:tags, "MetaSearch", meta_searches_tags_path]
    add_link[:tags, "Aliases", tag_aliases_path]
    add_link[:tags, "Implications", tag_implications_path]
    add_link[:tags, "Bulk Update Requests", bulk_update_requests_path]
    add_link[:tags, "Cheat sheet", help_page_path(id: "cheatsheet")]

    add_link[:notes, "Listing", notes_path]
    add_link[:notes, "Changes", note_versions_path]

    add_link[:pools, "Listing", gallery_pools_path]
    add_link[:pools, "Changes", pool_versions_path]

    add_link[:wiki, "Listing", wiki_pages_path]
    add_link[:wiki, "Changes", wiki_page_versions_path]

    add_link[:sets, "Listing", post_sets_path]
    add_link[:comments, "Listing", comments_path]
    add_link[:forum, "Listing", forum_topics_path]
    add_link[:blips, "Listing", blips_path]

    add_link[:users, "Listing", users_path]
    add_link[:users, "Bans", bans_path]
    add_link[:users, "Feedback", user_feedbacks_path]

    add_link[:staff, "Upload Whitelist", upload_whitelists_path]
    add_link[:staff, "Mod Actions", mod_actions_path]
    add_link[:staff, "Takedowns", takedowns_path]
    add_link[:staff, "Tickets", tickets_path]

    add_link[:tools, "Subscribestar", Danbooru.config.subscribestar_url] if Danbooru.config.subscribestar_url.present?
    add_link[:tools, "DB Export", Danbooru.config.db_export_path] if Danbooru.config.db_export_path.present?
    add_link[:tools, "Discord", discord_post_path] if CurrentUser.can_discord?
    add_link[:users, "Signup", new_user_path] if CurrentUser.is_anonymous?

    unless CurrentUser.is_anonymous?
      add_link[:users, "User Home", home_users_path]
      add_link[:users, "Profile", user_path(CurrentUser.user)]
      add_link[:users, "Settings", settings_users_path]
      add_link[:users, "Refresh counts", new_maintenance_user_count_fixes_path]
    end

    if CurrentUser.is_staff?
      add_link[:staff, "Mod Dashboard", moderator_dashboard_path]
      add_link[:posts, "Upload Listing", uploads_path]
    end

    add_link[:post_events, "Disapprovals", moderator_post_disapprovals_path] if CurrentUser.can_approve_posts?

    if CurrentUser.is_moderator?
      add_link[:staff, "Edit Histories", edit_histories_path]
      add_link[:staff, "Post Votes", index_post_votes_path]
      add_link[:users, "User Name Changes", user_name_change_requests_path]
    end

    if CurrentUser.is_admin?
      add_link[:admin, "Admin Dashboard", admin_dashboard_path]
      add_link[:admin, "Forum Categories", forum_categories_path]
      add_link[:admin, "IP Addresses", moderator_ip_addrs_path]
      add_link[:admin, "IP Bans", ip_bans_path]
      add_link[:admin, "Post Report Reasons", post_report_reasons_path]
      add_link[:admin, "Email Blacklist", email_blacklists_path]
      add_link[:admin, "Destroyed Posts", admin_destroyed_posts_path]
      add_link[:admin, "Exceptions", admin_exceptions_path]
      add_link[:admin, "Stuck DNP tags", new_admin_stuck_dnp_path]
      add_link[:admin, "Security", security_root_path]
      add_link[:admin, "Alt list", alt_list_admin_users_path]
      add_link[:admin, "SideKiq", sidekiq_path]
      add_link[:admin, "Settings", admin_settings_path] if CurrentUser.is_bd_staff?
    end

    add_link[:admin, "Reowner", new_admin_reowner_path] if CurrentUser.is_bd_staff?
    add_link[:users, "Staff Notes", staff_notes_path] if CurrentUser.can_view_staff_notes?

    add_link[:posts, "Help", help_page_path(id: "posts")]
    add_link[:artists, "Help", help_page_path(id: "artists")]
    add_link[:tags, "Help", help_page_path(id: "tags")]
    add_link[:notes, "Help", help_page_path(id: "notes")]
    add_link[:pools, "Help", help_page_path(id: "pools")]
    add_link[:sets, "Help", help_page_path(id: "sets")]
    add_link[:comments, "Help", help_page_path(id: "comments")]
    add_link[:forum, "Help", help_page_path(id: "forum")]
    add_link[:wiki, "Help", help_page_path(id: "wiki")]
    add_link[:blips, "Help", help_page_path(id: "blips")]
    add_link[:users, "Help", help_page_path(id: "accounts")]
    add_link[:tools, "Help Index", help_pages_path]

    sections
  end

  def format_wiki_page(name)
    wiki = WikiPage.titled(name)
    return WikiPage.new(body: "Wiki page \"#{name}\" not found.") if wiki.blank?
    wiki
  end
end
