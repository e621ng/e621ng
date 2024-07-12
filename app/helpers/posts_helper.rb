# frozen_string_literal: true

module PostsHelper
  def discover_mode?
    params[:tags] =~ /order:rank/
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

  def post_source_tag(source)
    # Only allow http:// and https:// links. Disallow javascript: links.
    if source =~ %r{\Ahttps?://}i
      source_link = decorated_link_to(source.sub(%r{\Ahttps?://(?:www\.)?}i, ""), source, target: "_blank", rel: "nofollow noreferrer noopener")

      if CurrentUser.is_janitor?
        source_link += " ".html_safe + link_to("»", posts_path(tags: "source:#{source.sub(%r{[^/]*$}, '')}"), rel: "nofollow")
      end

      source_link
    elsif source.start_with?("-")
      tag.s(source[1..])
    else
      source
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

  def is_pool_selected?(pool)
    return false if params.has_key?(:q)
    return false if params.has_key?(:post_set_id)
    return false unless params.has_key?(:pool_id)
    return params[:pool_id].to_i == pool.id
  end

  def is_post_set_selected?(post_set)
    return false if params.has_key?(:q)
    return false if params.has_key?(:pool_id)
    return false unless params.has_key?(:post_set_id)
    return params[:post_set_id].to_i == post_set.id
  end

  def post_stats_section(post)
    status_flags = []
    status_flags << 'P' if post.parent_id
    status_flags << 'C' if post.has_active_children?
    status_flags << 'U' if post.is_pending?
    status_flags << 'F' if post.is_flagged?

    post_score_icon = "#{'↑' if post.score > 0}#{'↓' if post.score < 0}#{'↕' if post.score == 0}"
    score = tag.span("#{post_score_icon}#{post.score}", class: "post-score-score #{score_class(post.score)}")
    favs = tag.span("♥#{post.fav_count}", class: "post-score-faves")
    comments = tag.span "C#{post.visible_comment_count(CurrentUser)}", class: 'post-score-comments'
    rating =  tag.span(post.rating.upcase, class: "post-score-rating")
    status = tag.span(status_flags.join(''), class: 'post-score-extras')
    tag.div score + favs + comments + rating + status, class: 'post-score', id: "post-score-#{post.id}"
  end

  def user_record_meta(user)
    positive = user.positive_feedback_count
    neutral = user.neutral_feedback_count
    negative = user.negative_feedback_count

    return "" unless positive > 0 || neutral > 0 || negative > 0
    positive_html = %{<span class="user-feedback-positive">#{positive} Pos</span>}.html_safe if positive > 0
    neutral_html = %{<span class="user-feedback-neutral">#{neutral} Neutral</span>}.html_safe if neutral > 0
    negative_html = %{<span class="user-feedback-negative">#{negative} Neg</span>}.html_safe if negative > 0

    link_to(%{(#{positive_html} #{neutral_html} #{negative_html})}.html_safe,  user_feedbacks_path(:search => {:user_id => user.id}))
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

  def post_vote_block(post, vote, buttons: false)
    voted = !vote.nil?
    vote_score = voted ? vote.score : 0
    post_score = post.score

    up_tag = tag.a(
      tag.span("▲", class: "post-vote-up-#{post.id} " + confirm_score_class(vote_score, 1, buttons)),
      class: "post-vote-up-link",
      data: { id: post.id },
    )
    down_tag = tag.a(
      tag.span("▼", class: "post-vote-down-#{post.id} " + confirm_score_class(vote_score, -1, buttons)),
      class: "post-vote-down-link",
      data: { id: post.id },
    )
    if buttons
      score_tag = tag.span(post.score, class: "post-score-#{post.id} post-score #{score_class(post_score)}", title: "#{post.up_score} up/#{post.down_score} down")
      CurrentUser.is_member? ? up_tag + score_tag + down_tag : ""
    else
      vote_block = tag.span(" (".html_safe + up_tag + " vote " + down_tag + ")")
      score_tag = tag.span(post.score, class: "post-score-#{post.id} post-score #{score_class(post_score)}", title: "#{post.up_score} up/#{post.down_score} down")
      score_tag + (CurrentUser.is_member? ? vote_block : "")
    end
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
end
