# frozen_string_literal: true

class PostsDecorator < ApplicationDecorator
  def self.collection_decorator_class
    PaginatedDecorator
  end

  delegate_all

  def preview_class(options)
    post = object
    klass = ["thumbnail"]
    klass << "pending" if post.is_pending?
    klass << "flagged" if post.is_flagged?
    klass << "deleted" if post.is_deleted?
    klass << "has-parent" if post.parent_id
    klass << "has-children" if post.has_visible_children?
    klass << "rating-safe" if post.rating == "s"
    klass << "rating-questionable" if post.rating == "q"
    klass << "rating-explicit" if post.rating == "e"
    klass << "blacklistable" unless options[:no_blacklist]
    klass
  end

  def data_attributes
    { data: object.thumbnail_attributes }
  end

  def score_class(score)
    return "score-neutral" if score == 0
    score > 0 ? "score-positive" : "score-negative"
  end

  def stats_section(template)
    post = object
    status_flags = []
    status_flags << "P" if post.parent_id
    status_flags << "C" if post.has_children?
    status_flags << "U" if post.is_pending?
    status_flags << "F" if post.is_flagged?

    post_score_icon = "#{'↑' if post.score > 0}#{'↓' if post.score < 0}#{'↕' if post.score == 0}"
    score = template.tag.span("#{post_score_icon}#{post.score}", class: "score #{score_class(post.score)}")
    favs = template.tag.span("♥#{post.fav_count}", class: "favorites")
    comments = template.tag.span "C#{post.visible_comment_count(CurrentUser)}", class: "comments"
    rating = template.tag.span(post.rating.upcase, class: "rating")
    # status = template.tag.span(status_flags.join, class: "extras")
    template.tag.div score + favs + comments + rating, class: "desc"
  end

  def preview_html(template, options = {})
    post = object

    if post.nil? ||
       (!options[:show_deleted] && post.is_deleted? && TagQuery.should_hide_deleted_posts?(options[:tags], at_any_level: true)) ||
       post.loginblocked? || post.safeblocked?
      return ""
    end

    article_attrs = {
      "id" => "post_#{post.id}",
      "class" => preview_class(options).join(" "),
    }.merge(data_attributes)

    link_target = options[:link_target] || post

    link_params = {}
    if options[:tags].present?
      link_params["q"] = options[:tags]
    end
    if options[:pool_id]
      link_params["pool_id"] = options[:pool_id]
    end
    if options[:post_set_id]
      link_params["post_set_id"] = options[:post_set_id]
    end

    tooltip = "Rating: #{post.rating}\nID: #{post.id}\nDate: #{post.created_at}\nStatus: #{post.status}\nScore: #{post.score}"
    if CurrentUser.is_janitor?
      tooltip += "\nUploader: #{post.uploader_name}"
      if post.is_flagged? || post.is_deleted?
        flag = post.flags.order(id: :desc).first
        tooltip += "\nFlag Reason: #{flag&.reason}" if post.is_flagged?
        tooltip += "\nDel Reason: #{flag&.reason}" if post.is_deleted?
      end
    end
    tooltip += "\n\n#{post.tag_string}"

    preview_url = preview_file_url_pair

    alt_text = "post ##{post.id}"

    img_contents = template.link_to template.polymorphic_path(link_target, link_params), data: { hover_text: tooltip } do
      template.tag.picture do
        template.concat template.tag.source type: "image/webp", srcset: preview_url[0] if Danbooru.config.webp_previews_enabled?
        template.concat template.tag.source type: "image/jpeg", srcset: preview_url[1]
        template.concat template.tag.img src: preview_url[1], alt: alt_text
      end
    end
    desc_contents = options[:stats] ? stats_section(template) : "".html_safe
    template.tag.article(**article_attrs) do
      img_contents + desc_contents
    end
  end
end
