# frozen_string_literal: true

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

  def decorated_nav_link_to(text, icon, url, **options)
    klass = options.delete(:class)

    if nav_link_match(params[:controller], url)
      klass = "#{klass} current"
    end

    id = "nav-#{text.downcase.gsub(/[^a-z ]/, '').parameterize}"

    tag.li(id: id, class: klass) do
      link_to(url, id: "#{id}-link", **options) do
        concat svg_icon(icon)
        concat " "
        concat tag.span(text)
      end
    end
  end

  def custom_image_nav_link_to(text, image, url, **options)
    klass = options.delete(:class)

    if nav_link_match(params[:controller], url)
      klass = "#{klass} current"
    end

    id = "nav-#{text.downcase.gsub(/[^a-z ]/, '').parameterize}"

    tag.li(id: id, class: klass) do
      link_to(url, id: "#{id}-link", **options) do
        concat image_pack_tag(image)
        concat " "
        concat tag.span(text)
      end
    end
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

  def compact_date(time)
    time_tag(time.strftime("%Y-%m-%d"), time)
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
    attributes = %i[id name level level_string can_approve_posts? can_upload_free? per_page]
    attributes += User::Roles.map { |role| :"is_#{role}?" }

    controller_param = params[:controller].parameterize.dasherize
    action_param = params[:action].parameterize.dasherize

    {
      lang: "en",
      class: "c-#{controller_param} a-#{action_param} #{'resp' unless disable_mobile_mode?}",
      data: {
        controller: controller_param,
        action: action_param,
        **data_attributes_for(user, "user", attributes),
        disable_cropped_thumbnails: Danbooru.config.enable_image_cropping? && CurrentUser.user.disable_cropped_thumbnails?,
      },
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
    tag.div class: "post-thumb placeholder", id: "tp-#{post_id}", data: { id: post_id } do
      tag.img class: "thumb-img placeholder", src: "/images/thumb-preview.png", height: 150, width: 150
    end
  end

  def unread_dmails(user)
    if user.has_mail?
      "(#{user.unread_dmail_count})"
    else
      ""
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
end
