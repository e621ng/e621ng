# frozen_string_literal: true

module PostsHelper
  def discover_mode?
    params[:tags].to_s =~ /order:hot/
  end

  def next_page_url
    current_page = (params[:page] || 1).to_i
    url_for(nav_params_for(current_page + 1)).html_safe
  end

  def prev_page_url
    current_page = (params[:page] || 1).to_i
    if current_page >= 2
      url_for(nav_params_for(current_page - 1)).html_safe
    else
      nil
    end
  end

  def try_parse_http_url(source)
    # This will do a better job at handling technically invalid URLs like
    # http:example.com, http:/example.com or just example.com
    url = Addressable::URI.heuristic_parse(source)
    # Only allow http:// and https:// links. Disallow javascript: links.
    if %w[http https].include?(url.scheme)
      url
    end
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def post_source_tag(source)
    if source.start_with?("-")
      tag.s(source[1..])
    elsif (url = try_parse_http_url(source)).present?
      # remove http(s): and any leading and trailing slashes
      short_url = url.omit(:scheme).to_s.sub(%r{^/+}, "").sub(%r{/+$}, "")
      source_link = decorated_link_to(short_url, url.to_s, target: "_blank", rel: "nofollow noreferrer noopener")

      if CurrentUser.is_janitor?
        # remove ?query=test#example
        url_no_final_path = url.omit(:query, :fragment)
        # remove last /part
        url_no_final_path.path = url_no_final_path.path.sub(%r{[^/]*$}, "")
        # remove any remaining trailing slashes
        url_no_final_path = url_no_final_path.to_s.sub(%r{/+$}, "")
        source_link += " ".html_safe + link_to("»", posts_path(tags: "source:#{url_no_final_path}"), rel: "nofollow")
      end

      source_link
    else
      tag.span(source, class: "source-invalid")
    end
  end

  def has_parent_message(post, parent_post_set)
    html = +""

    html << "Parent: "
    html << link_to("post ##{post.parent_id}", post_path(id: post.parent_id))
    html << " (deleted)" if parent_post_set.parent.first.is_deleted?

    sibling_count = parent_post_set.children.count - 1
    if sibling_count > 0
      html << " that has "
      text = sibling_count == 1 ? "a sibling" : "#{sibling_count} siblings"
      html << link_to(text, posts_path(:tags => "parent:#{post.parent_id}"))
    end

    html << " (#{link_to("learn more", wiki_pages_path(:title => "e621:post_relationships"))}) "

    html << link_to("show »", "#", id: "has-parent-relationship-preview-link")

    html.html_safe
  end

  def has_children_message(post, children_post_set)
    html = +""

    html << "Children: "
    text = children_post_set.children.count == 1 ? "1 child" : "#{children_post_set.children.count} children"
    html << link_to(text, posts_path(:tags => "parent:#{post.id}"))

    html << " (#{link_to("learn more", wiki_pages_path(:title => "e621:post_relationships"))}) "

    html << link_to("show »", "#", id: "has-children-relationship-preview-link")

    html.html_safe
  end

  def is_pool_selected?(pool, selected: nil)
    return false if selected.blank?
    return false if params.key?(:q)
    return false if params.key?(:post_set_id)
    selected == pool.id
  end

  def is_post_set_selected?(post_set, selected: nil)
    return false if selected.blank?
    return false if params.key?(:q)
    return false if params.key?(:pool_id)
    selected == post_set.id
  end

  def post_stats_section(post)
    status_flags = []
    status_flags << "P" if post.parent_id
    status_flags << "C" if post.has_active_children?
    status_flags << "U" if post.is_pending?
    status_flags << "F" if post.is_flagged?

    post_score_icon = "#{'↑' if post.score > 0}#{'↓' if post.score < 0}#{'↕' if post.score == 0}"
    score = tag.span("#{post_score_icon}#{post.score}", class: "score #{score_class(post.score)}")
    favs = tag.span("♥#{post.fav_count}", class: "favorites")
    comments = tag.span "C#{post.visible_comment_count(CurrentUser)}", class: "comments"
    rating = tag.span(post.rating.upcase, class: "rating")
    # status = tag.span(status_flags.join, class: "extras")
    tag.div score + favs + comments + rating, class: "desc"
  end

  private

  def nav_params_for(page)
    query_params = params.except(:controller, :action, :id).merge(page: page).permit!
    {params: query_params}
  end

  def pretty_html_rating(post)
    rating_text = post.pretty_rating
    rating_class = "post-rating-text-#{rating_text.downcase}"
    tag.span(rating_text, id: "post-rating-text", class: rating_class)
  end

  def post_score_block(post)
    tag.span(post.score, class: "post-score-#{post.id} post-score #{score_class(post.score)}", title: "#{post.up_score} up/#{post.down_score} down")
  end

  def post_score_state(post)
    return 0 if post.nil? || post.score == 0
    post.score > 0 ? 1 : -1
  end

  def score_class(score)
    return 'score-neutral' if score == 0
    score > 0 ? 'score-positive' : 'score-negative'
  end

  def confirm_score_class(score, want, buttons)
    base = buttons ? 'button ' : ''
    return base + 'score-neutral' if score != want || score == 0
    base + score_class(score)
  end

  def rating_collection
    [
      ["Safe", "s"],
      ["Questionable", "q"],
      ["Explicit", "e"]
    ]
  end

  def post_short_url(post)
    short_id = post.id.to_s(32)
    url_for(controller: "posts_short", action: "show", id: short_id, only_path: false)
  end
end
