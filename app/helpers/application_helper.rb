module ApplicationHelper
  def disable_mobile_mode?
    if CurrentUser.user.present? && CurrentUser.is_member?
      return CurrentUser.disable_responsive_mode?
    end
    cookies[:nmm].present?
  end


  def diff_list_html(new, old, latest)
    diff = SetDiff.new(new, old, latest)
    render "diff_list", diff: diff
  end

  def wordbreakify(string)
    lines = string.scan(/.{1,10}/)
    wordbreaked_string = lines.map{|str| h(str)}.join("<wbr>")
    raw(wordbreaked_string)
  end

  def nav_link_to(text, url, **options)
    klass = options.delete(:class)

    if nav_link_match(params[:controller], url)
      klass = "#{klass} current"
    end

    li_link_to(text, url, id_prefix: "nav-", class: klass, **options)
  end

  def subnav_link_to(text, url, **)
    li_link_to(text, url, id_prefix: "subnav-", **)
  end

  def li_link_to(text, url, id_prefix: "", **options)
    klass = options.delete(:class)
    id = id_prefix + text.downcase.gsub(/[^a-z ]/, "").parameterize
    tag.li(link_to(text, url, id: "#{id}-link", **options), id: id, class: klass)
  end

  def dtext_ragel(text, **)
    parsed = DText.parse(text, **)
    return raw "" if parsed.nil?
    deferred_post_ids.merge(parsed[1]) if parsed[1].present?
    raw parsed[0]
  rescue DText::Error => e
    raw ""
  end

  def format_text(text, **options)
    # preserve the currrent inline behaviour
    if options[:inline]
      dtext_ragel(text, **options)
    else
      raw %(<div class="styled-dtext">#{dtext_ragel(text, **options)}</div>)
    end
  end

  def custom_form_for(object, *args, &)
    options = args.extract_options!
    simple_form_for(object, *(args << options.merge(builder: CustomFormBuilder)), &)
  end

  def error_messages_for(instance_name)
    instance = instance_variable_get("@#{instance_name}")

    if instance && instance.errors.any?
      %{<div class="error-messages ui-state-error ui-corner-all"><strong>Error</strong>: #{instance.__send__(:errors).full_messages.join(", ")}</div>}.html_safe
    else
      ""
    end
  end

  def time_tag(content, time)
    datetime = time.strftime("%Y-%m-%dT%H:%M%:z")
    tag.time(content || datetime, datetime: datetime, title: time.to_fs)
  end

  def time_ago_in_words_tagged(time, compact: false)
    if time.past?
      text = time_ago_in_words(time) + " ago"
      text = text.gsub(/almost|about|over/, "") if compact
      raw time_tag(text, time)
    else
      raw time_tag("in " + distance_of_time_in_words(Time.now, time), time)
    end
  end

  def compact_time(time)
    time_tag(time.strftime("%Y-%m-%d %H:%M"), time)
  end

  def external_link_to(url, truncate: nil, strip_scheme: false, link_options: {})
    text = url
    text = text.gsub(%r!\Ahttps?://!i, "") if strip_scheme
    text = text.truncate(truncate) if truncate

    if url =~ %r!\Ahttps?://!i
      link_to text, url, {rel: :nofollow}.merge(link_options)
    else
      url
    end
  end

  def link_to_ip(ip)
    return '(none)' unless ip
    link_to ip, moderator_ip_addrs_path(:search => {:ip_addr => ip})
  end

  def link_to_user(user, include_activation: false)
    return "anonymous" if user.blank?

    user_class = user.level_css_class
    user_class += " user-post-approver" if user.can_approve_posts?
    user_class += " user-post-uploader" if user.can_upload_free?
    user_class += " user-banned" if user.is_banned?
    user_class += " with-style" if CurrentUser.user.style_usernames?
    html = link_to(user.pretty_name, user_path(user), class: user_class, rel: "nofollow")
    html << " (Unactivated)" if include_activation && !user.is_verified?
    html
  end

  def body_attributes(user = CurrentUser.user)
    attributes = [:id, :name, :level, :level_string, :can_approve_posts?, :can_upload_free?, :per_page]
    attributes += User::Roles.map { |role| :"is_#{role}?" }

    controller_param = params[:controller].parameterize.dasherize
    action_param = params[:action].parameterize.dasherize

    {
      lang: "en",
      class: "c-#{controller_param} a-#{action_param} #{"resp" unless disable_mobile_mode?}",
      data: {
        controller: controller_param,
        action: action_param,
        **data_attributes_for(user, "user", attributes)
      }
    }
  end

  def data_attributes_for(record, prefix, attributes)
    attributes.map do |attr|
      name = attr.to_s.dasherize.delete("?")
      value = record.send(attr)

      [:"#{prefix}-#{name}", value]
    end.to_h
  end

  def user_avatar(user)
    return "" if user.nil?
    post_id = user.avatar_id
    return "" unless post_id
    deferred_post_ids.add(post_id)
    tag.div class: 'post-thumb placeholder', id: "tp-#{post_id}", 'data-id': post_id do
      tag.img class: 'thumb-img placeholder', src: '/images/thumb-preview.png', height: 100, width: 100
    end
  end

protected
  def nav_link_match(controller, url)
    # Static routes must match completely
    return url == request.path if controller == "static"

    url =~ case controller
    when "sessions", "users", "maintenance/user/login_reminders", "maintenance/user/password_resets", "admin/users", "dmails"
      /^\/(session|users)/

    when "post_sets"
      /^\/post_sets/

    when "blips"
      /^\/blips/

    when "forum_posts"
      /^\/forum_topics/

    when "comments"
      /^\/comments/

    when "notes", "note_versions"
      /^\/notes/

    when "posts", "uploads", "post_versions", "popular", "moderator/post/dashboards", "favorites", "post_favorites"
      /^\/posts/

    when "artists", "artist_versions"
      /^\/artist/

    when "tags", "meta_searches", "tag_aliases", "tag_alias_requests", "tag_implications", "tag_implication_requests", "related_tags"
      /^\/tags/

    when "pools", "pool_versions"
      /^\/pools/

    when "moderator/dashboards"
      /^\/moderator/

    when "wiki_pages", "wiki_page_versions"
      /^\/wiki_pages/

    when "forum_topics", "forum_posts"
      /^\/forum_topics/

    when "help"
      /^\/help/

    # If there is no match activate the site map only
    else
      /^#{site_map_path}/
    end
  end

  # Every time this list changes:
  # - generate and optimize a new spritesheet file
  # - update the spritesheet dimensions in the CSS
  # - regenerate the alias list

  DECORATABLE_DOMAINS = [
    nil, # default
    "e621.net",
    #
    # Aggregators
    "linktr.ee",
    "carrd.co",
    #
    # Art sites
    "artstation.com",
    "archiveofourown.com",
    "aryion.com",
    "derpibooru.org",
    "deviantart.com",
    "furaffinity.net",
    "furrynetwork.com",
    "furrystation.com",
    "hentai-foundry.com",
    "hiccears.com",
    "imgur.com",
    "inkbunny.net",
    "itaku.ee",
    "pillowfort.social",
    "pixiv.net",
    "skeb.jp",
    "sofurry.com",
    "toyhou.se",
    "tumblr.com",
    "newgrounds.com",
    "weasyl.com",
    "webtoons.com",
    #
    # Social media
    "aethy.com",
    "baraag.net",
    "bsky.app",
    "cohost.org",
    "facebook.com",
    "instagram.com",
    "pawoo.net",
    "plurk.com",
    "privatter.net",
    "reddit.com",
    "tiktok.com",
    "twitter.com",
    "vk.com",
    "weibo.com",
    "youtube.com",
    #
    # Livestreams
    "picarto.tv",
    "piczel.tv",
    "twitch.tv",
    #
    # Paysites
    "artconomy.com",
    "boosty.to",
    "buymeacoffee.com",
    "commishes.com",
    "gumroad.com",
    "etsy.com",
    "fanbox.cc",
    "itch.io",
    "ko-fi.com",
    "patreon.com",
    "redbubble.com",
    "subscribestar.adult",
    #
    # Bulk storage
    "amazonaws.com",
    "catbox.moe",
    "drive.google.com",
    "dropbox.com",
    "mega.nz",
    "onedrive.live.com",
    #
    # Imageboards
    "4chan.org",
    "danbooru.donmai.us",
    "desuarchive.org",
    "e-hentai.org",
    "gelbooru.com",
    "rule34.paheal.net",
    "rule34.xxx",
    "u18chan.com",
    #
    # Other
    "curiouscat.me",
    "discord.com",
    "steamcommunity.com",
    "t.me",
    "trello.com",
    "web.archive.org",
  ].freeze

  DECORATABLE_ALIASES = {
    # alt names
    "e926.net" => DECORATABLE_DOMAINS.find_index("e621.net"),
    "discord.gg" => DECORATABLE_DOMAINS.find_index("discord.com"),
    "pixiv.me" => DECORATABLE_DOMAINS.find_index("pixiv.net"),
    "x.com" => DECORATABLE_DOMAINS.find_index("twitter.com"),

    # same icon
    "cloudfront.net" => DECORATABLE_DOMAINS.find_index("amazonaws.com"),
    "mastodon.art" => DECORATABLE_DOMAINS.find_index("baraag.net"),
    "meow.social" => DECORATABLE_DOMAINS.find_index("baraag.net"),
    "sta.sh" => DECORATABLE_DOMAINS.find_index("deviantart.com"),

    # image servers
    "4cdn.org" => DECORATABLE_DOMAINS.find_index("4chan.org"),
    "discordapp.com" => DECORATABLE_DOMAINS.find_index("discord.com"),
    "derpicdn.net" => DECORATABLE_DOMAINS.find_index("derpibooru.org"),
    "dropboxusercontent.com" => DECORATABLE_DOMAINS.find_index("dropbox.com"),
    "facdn.net" => DECORATABLE_DOMAINS.find_index("furaffinity.net"),
    "fbcdn.net" => DECORATABLE_DOMAINS.find_index("facebook.com"),
    "ib.metapix.net" => DECORATABLE_DOMAINS.find_index("inkbunny.net"),
    "ngfiles.com" => DECORATABLE_DOMAINS.find_index("newgrounds.com"),
    "pximg.net" => DECORATABLE_DOMAINS.find_index("pixiv.net"),
    "redd.it" => DECORATABLE_DOMAINS.find_index("reddit.com"),
    "twimg.com" => DECORATABLE_DOMAINS.find_index("twitter.com"),
    "ungrounded.net" => DECORATABLE_DOMAINS.find_index("newgrounds.com"),
    "wixmp.com" => DECORATABLE_DOMAINS.find_index("deviantart.com"),
  }.freeze

  def decorated_link_to(text, path, **)
    begin
      uri = URI.parse(path)
    rescue URI::InvalidURIError
      return link_to(text, path, **)
    end

    hostname = uri.host
    hostname = hostname[4..] if hostname.match(/^www\./)

    # First attempt: direct match
    index = DECORATABLE_DOMAINS.find_index(hostname)

    # Second attempt: subdomains?
    if index.nil?
      parts = hostname.split(".")
      hostname = parts.drop(1).join(".") if parts.length > 2
      index = DECORATABLE_DOMAINS.find_index(hostname)

      # Third attempt: aliases
      index = DECORATABLE_ALIASES[hostname] if index.nil?
    end

    # Calculate the coordinates
    index = 0 if index.nil?
    x = 0 - (index.modulo(8) * 16)
    y = 0 - ((index / 8).floor * 16)

    link_to(path, class: "decorated", **) do
      safe_join([
        tag.span(
          class: "link-decoration",
          style: "background-position: #{x}px #{y}px",
          data: {
            hostname: hostname,
            index: index,
            lookup: DECORATABLE_ALIASES[hostname].to_s,
            isNil: DECORATABLE_ALIASES[hostname].nil?,
          },
        ),
        text,
      ])
    end
  end
end
