# frozen_string_literal: true

# Declarative registry backing the site map (/static/site_map).
#
# This is the single source of truth for the site map: every linkable page is declared once with
# its display label, group, and access level. Two specs keep it honest:
# - spec/logical/site_map_spec.rb (route coverage)
# - spec/requests/site_map_gate_spec.rb (access-level probe)
module SiteMap
  extend self
  include Rails.application.routes.url_helpers

  # Closed set of reasons a linkable index route may be kept out of the map.
  EXCLUDE_REASONS = %i[utility main_nav internal requires_context].freeze

  Group = Struct.new(:key, :title, keyword_init: true)
  Entry = Struct.new(:group, :route, :label, :level, :params, :inline_reason, :visible, :url, :path_proc, keyword_init: true)
  Exclusion = Struct.new(:route, :reason, keyword_init: true)

  @groups = []
  @entries = []
  @exclusions = []

  class << self
    attr_reader :groups, :entries, :exclusions
  end

  # Path helpers (from url_helpers) call this; only `*_path` helpers are used,
  # so an empty host config is sufficient.
  def default_url_options
    {}
  end

  # --- DSL -------------------------------------------------------------------

  # Declare a site-map section, in display order.
  def group(key, title)
    @groups << Group.new(key: key, title: title)
  end

  # Declare a linkable page.
  #
  #   level:   UserLevel required to reach the page. Omitted => public.
  #            Runtime visibility is `user.level >= level`; verified by the probe.
  #   gate:    { inline: "<reason>" } opts the entry out of the probe for gates
  #            that are not a level boundary (feature flag, account-age, record
  #            state). Requires a `visible:` predicate for runtime.
  #   visible: runtime predicate over the user; only used for inline gates.
  #   params:  args for param-routes (e.g. help pages).
  #   url:     lambda producing an external/computed URL (no route). Implies inline.
  #   path:    lambda(user) building an internal path that needs the user (e.g. Profile).
  def page(group_key, route, label, **opts)
    level = opts[:level]
    url = opts[:url]
    path = opts[:path]
    visible = opts[:visible]
    inline_reason = gate_reason(opts[:gate])
    inline_reason ||= "external link" if url

    raise ArgumentError, "#{label}: cannot combine level: with an inline gate" if inline_reason && level
    raise ArgumentError, "#{label}: needs a route, url:, or path:" if route.nil? && url.nil? && path.nil?
    raise ArgumentError, "#{label}: inline gate needs a visible: predicate" if inline_reason && visible.nil? && url.nil?

    @entries << Entry.new(
      group: group_key, route: route, label: label, level: level, params: opts[:params] || {},
      inline_reason: inline_reason, visible: visible, url: url, path_proc: path
    )
  end

  # Declare linkable index routes that are deliberately absent from the map.
  def exclude(*route_names, reason:)
    raise ArgumentError, "unknown exclude reason #{reason.inspect}" unless EXCLUDE_REASONS.include?(reason)
    route_names.each { |name| @exclusions << Exclusion.new(route: name, reason: reason) }
  end

  # --- Rendering -------------------------------------------------------------

  # Sections visible to `user`, in the structure the view consumes:
  #   [{ key:, title:, links: [{ label:, path: }] }]
  # Empty groups are kept here; the view drops them (`next if links.blank?`).
  def sections_for(user)
    @groups.map do |grp|
      links = @entries.select { |entry| entry.group == grp.key && visible_to?(entry, user) }
                      .map { |entry| { label: entry.label, path: resolve_path(entry, user) } }
      { key: grp.key, title: grp.title, links: links }
    end
  end

  # --- Introspection (used by specs) -----------------------------------------

  # Entries the probe can drive: those gated by a level boundary (or public).
  def probeable_entries
    @entries.reject(&:inline_reason)
  end

  # Static path for a probeable entry (never depends on the user).
  def probe_path(entry)
    public_send("#{entry.route}_path", **entry.params)
  end

  def registered_route_names
    @entries.filter_map(&:route)
  end

  def excluded_route_names
    @exclusions.map(&:route)
  end

  private

  def gate_reason(gate)
    return nil if gate.nil?
    raise ArgumentError, "gate: must be { inline: \"reason\" }" unless gate.is_a?(Hash) && gate[:inline].present?
    gate[:inline]
  end

  def visible_to?(entry, user)
    if entry.inline_reason
      entry.visible ? entry.visible.call(user) : true
    elsif entry.level
      user.level >= entry.level
    else
      true
    end
  end

  def resolve_path(entry, user)
    if entry.url
      entry.url.call
    elsif entry.path_proc
      entry.path_proc.call(user)
    else
      public_send("#{entry.route}_path", **entry.params)
    end
  end

  # ===========================================================================
  # Registry
  # ===========================================================================

  # --- Posts ---
  group :posts, "Posts"
  page :posts, :posts, "Listing"
  page :posts, :new_upload, "Upload", level: UserLevel::MEMBER
  page :posts, :popular_index, "Popular"
  page :posts, :favorites, "Favorites",
       gate: { inline: "shows the current user's favorites; 404s without a user_id when logged out" },
       visible: ->(u) { u.is_logged_in? }
  page :posts, :post_versions, "Changes"
  page :posts, :iqdb_queries, "Similar Images Search"
  page :posts, :deleted_posts, "Deleted Index"
  page :posts, :uploads, "Upload Listing", level: UserLevel::STAFF
  page :posts, :help_page, "Help", params: { id: "posts" }

  # --- Post Events ---
  group :post_events, "Post Events"
  page :post_events, :post_events, "Listing"
  page :post_events, :post_versions, "Tag Changes"
  page :post_events, :post_approvals, "Approvals"
  page :post_events, :post_flags, "Flags"
  page :post_events, :post_replacements, "Replacements"
  page :post_events, :staff_post_disapprovals, "Disapprovals",
       gate: { inline: "approver flag, not a level boundary" }, visible: ->(u) { u.can_approve_posts? }

  # --- Tools ---
  group :tools, "Tools"
  page :tools, :news_updates, "News Updates"
  page :tools, :mascots, "Mascots"
  page :tools, :furid, "FurID"
  page :tools, :keyboard_shortcuts, "Keyboard Shortcuts"
  page :tools, :stats, "Stats"
  page :tools, :terms_of_use, "Terms of Use"
  page :tools, :privacy_policy, "Privacy Policy"
  page :tools, :code_of_conduct, "Code of Conduct"
  page :tools, :discord_post, "Discord",
       gate: { inline: "account-age + flags (can_discord?)" }, visible: ->(u) { u.can_discord? }
  page :tools, :privacy_discordbot, "Discord Bot Privacy Policy"
  page :tools, :help_pages, "Help Index"

  # --- Artists ---
  group :artists, "Artists"
  page :artists, :artists, "Listing"
  page :artists, :artist_urls, "URLs"
  page :artists, :avoid_postings, "Avoid Posting Entries"
  page :artists, :avoid_posting_static, "Avoid Posting List"
  page :artists, :artist_versions, "Changes"
  page :artists, :help_page, "Help", params: { id: "artists" }

  # --- Tags ---
  group :tags, "Tags"
  page :tags, :tags, "Listing"
  page :tags, :tag_type_versions, "Type Changes"
  page :tags, :search_trends, "Search Trends"
  page :tags, :meta_searches_tags, "MetaSearch"
  page :tags, :tag_aliases, "Aliases"
  page :tags, :tag_implications, "Implications"
  page :tags, :bulk_update_requests, "Bulk Update Requests"
  page :tags, :help_page, "Cheat sheet", params: { id: "cheatsheet" }
  page :tags, :help_page, "Help", params: { id: "tags" }

  # --- Notes ---
  group :notes, "Notes"
  page :notes, :notes, "Listing"
  page :notes, :note_versions, "Changes"
  page :notes, :help_page, "Help", params: { id: "notes" }

  # --- Pools ---
  group :pools, "Pools"
  page :pools, :pools, "Listing"
  page :pools, :gallery_pools, "Gallery"
  page :pools, :pool_versions, "Changes", level: UserLevel::MEMBER
  page :pools, :help_page, "Help", params: { id: "pools" }

  # --- Sets ---
  group :sets, "Sets"
  page :sets, :post_sets, "Listing"
  page :sets, :help_page, "Help", params: { id: "sets" }

  # --- Comments ---
  group :comments, "Comments"
  page :comments, :comments, "Listing"
  page :comments, :help_page, "Help", params: { id: "comments" }

  # --- Forum ---
  group :forum, "Forum"
  page :forum, :forum_topics, "Listing"
  page :forum, :forum_categories, "Categories", level: UserLevel::ADMIN
  page :forum, :help_page, "Help", params: { id: "forum" }

  # --- Wiki ---
  group :wiki, "Wiki"
  page :wiki, :wiki_pages, "Listing"
  page :wiki, :wiki_page_versions, "Changes"
  page :wiki, :help_page, "Help", params: { id: "wiki" }

  # --- Blips ---
  group :blips, "Blips"
  page :blips, :blips, "Listing"
  page :blips, :help_page, "Help", params: { id: "blips" }

  # --- Users ---
  group :users, "Users"
  page :users, :users, "Listing"
  page :users, :bans, "Bans"
  page :users, :user_feedbacks, "Feedback"
  page :users, :new_user, "Signup",
       gate: { inline: "logged-out only" }, visible: ->(u) { u.is_logged_out? }
  page :users, :home_users, "User Home",
       gate: { inline: "logged-in only" }, visible: ->(u) { u.is_logged_in? }
  page :users, nil, "Profile",
       path: ->(u) { user_path(u) }, gate: { inline: "logged-in only" }, visible: ->(u) { u.is_logged_in? }
  page :users, :settings_users, "Settings",
       gate: { inline: "logged-in only" }, visible: ->(u) { u.is_logged_in? }
  page :users, :new_maintenance_user_count_fixes, "Refresh counts", level: UserLevel::MEMBER
  page :users, :dmails, "DMails", level: UserLevel::MEMBER
  page :users, :help_page, "Help", params: { id: "accounts" }

  # --- Staff ---
  group :staff, "Staff"
  page :staff, :mod_actions, "Mod Actions"
  page :staff, :upload_whitelists, "Upload Whitelist"
  page :staff, :edit_histories, "Edit Histories", level: UserLevel::MODERATOR
  page :staff, :staff_automod_dmails, "AutoMod DMails", level: UserLevel::STAFF
  page :staff, :staff_notes, "Staff Notes",
       gate: { inline: "can_view_staff_notes flag" }, visible: ->(u) { u.can_view_staff_notes? }
  page :staff, :staff_wikis, "Staff Wiki", level: UserLevel::STAFF
  page :staff, :staff_files, "Staff Files", level: UserLevel::STAFF

  # --- Janitor ---
  group :janitor, "Janitor"
  page :janitor, :appeals, "Appeals"
  page :janitor, :new_staff_stuck_dnp, "Stuck DNP tags", level: UserLevel::ADMIN
  page :janitor, :post_report_reasons, "Post Report Reasons", level: UserLevel::ADMIN
  page :janitor, :post_flag_reasons, "Post Flag Reasons", level: UserLevel::ADMIN
  page :janitor, :new_staff_reowner, "Reowner",
       gate: { inline: "bd_staff flag" }, visible: ->(u) { u.is_bd_staff? }
  page :janitor, :staff_destroyed_posts, "Destroyed Posts", level: UserLevel::ADMIN

  # --- Moderator ---
  group :moderator, "Moderator"
  page :moderator, :tickets, "Tickets"
  page :moderator, :ip_bans, "IP Bans", level: UserLevel::ADMIN
  page :moderator, :staff_ip_addrs, "IP Addresses", level: UserLevel::ADMIN
  page :moderator, :alt_list_staff_users, "Alt list", level: UserLevel::ADMIN
  page :moderator, :staff_automod_rules, "AutoMod Rules", level: UserLevel::ADMIN
  page :moderator, :index_post_votes, "Post Votes", level: UserLevel::MODERATOR
  page :moderator, :user_name_change_requests, "User Name Changes", level: UserLevel::MODERATOR
  page :moderator, :staff_moderator_dashboard, "Mod Dashboard", level: UserLevel::STAFF

  # --- Admin ---
  group :admin, "Admin"
  page :admin, :staff_security_index, "Security", level: UserLevel::ADMIN
  page :admin, :email_blacklists, "Email Blacklist", level: UserLevel::ADMIN
  page :admin, :staff_admin_dashboard, "Admin Dashboard", level: UserLevel::ADMIN
  page :admin, :takedowns, "Takedowns"

  # --- Developer ---
  group :developer, "Developer"
  page :developer, :help_page, "API Documentation", params: { id: "api" }
  page :developer, nil, "Source Code", url: -> { Danbooru.config.source_code_url }
  page :developer, :db_exports, "DB Export",
       gate: { inline: "feature flag (db_export_enabled?)" }, visible: ->(_u) { Danbooru.config.db_export_enabled? }
  page :developer, :staff_exceptions, "Exceptions", level: UserLevel::STAFF
  page :developer, :sidekiq, "SideKiq",
       gate: { inline: "mounted Sidekiq::Web engine, guarded by AdminRouteConstraint" }, visible: ->(u) { u.is_admin? }

  # ---------------------------------------------------------------------------
  # Excluded index routes — linkable but deliberately kept out of the map.
  # Each must be justified; the coverage spec fails if a new index route is
  # neither a page nor listed here. Some of these (staff wikis/files, avoid-
  # posting changes) are plausible future additions, deferred to keep this
  # change behaviour-preserving.
  # ---------------------------------------------------------------------------
  exclude :api_keys, reason: :requires_context
  exclude :forum_posts, reason: :main_nav
  exclude :avoid_posting_versions, :search_trend_blacklists, :search_trend_hourlies,
          :staff_wiki_versions, :post_set_maintainers, reason: :utility
  exclude :oauth_applications, :oauth_authorized_applications, :preview_view_components,
          :staff_discord_reports, :staff_vote_trends, reason: :internal
end
