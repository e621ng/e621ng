class PostPresenter < Presenter
  attr_reader :pool, :next_post_in_pool
  delegate :tag_list_html, :split_tag_list_html, :split_tag_list_text, :inline_tag_list_html, to: :tag_set_presenter

  def self.preview(post, options = {})
    if post.nil?
      return "<em>none</em>".html_safe
    end

    if !options[:show_deleted] && post.is_deleted? && options[:tags] !~ /(?:status:(?:all|any|deleted))|(?:deletedby:)|(?:delreason:)/ && !options[:raw]
      return ""
    end

    if post.loginblocked? || post.safeblocked?
      return ""
    end

    if post.is_ugoira? && !post.has_ugoira_webm?
      # ugoira preview gen is async so dont render it immediately
      return ""
    end

    options[:stats] |= !options[:avatar] && !options[:inline]

    locals = {}

    locals[:article_attrs] = {
      "id" => "post_#{post.id}",
      "class" => preview_class(post, options).join(" ")
    }.merge(data_attributes(post))

    locals[:link_target] = options[:link_target] || post

    locals[:link_params] = {}
    if options[:tags].present?
      locals[:link_params]["q"] = options[:tags]
    end
    if options[:pool_id]
      locals[:link_params]["pool_id"] = options[:pool_id]
    end
    if options[:post_set_id]
      locals[:link_params]["post_set_id"] = options[:post_set_id]
    end

    locals[:tooltip] = "Rating: #{post.rating}\nID: #{post.id}\nDate: #{post.created_at}\nStatus: #{post.status}\nScore: #{post.score}\n\n#{post.tag_string}"

    locals[:cropped_url] = if Danbooru.config.enable_image_cropping && options[:show_cropped] && post.has_cropped? && !CurrentUser.user.disable_cropped_thumbnails?
      post.crop_file_url
    else
      post.preview_file_url
    end

    locals[:cropped_url] = Danbooru.config.deleted_preview_url if post.deleteblocked?
    locals[:preview_url] = if post.deleteblocked?
                             Danbooru.config.deleted_preview_url
                           else
                             post.preview_file_url
                           end

    locals[:alt_text] = post.tag_string

    locals[:has_cropped] = post.has_cropped?

    if options[:pool]
      locals[:pool] = options[:pool]
    else
      locals[:pool] = nil
    end

    locals[:width] = post.image_width
    locals[:height] = post.image_height

    if options[:similarity]
      locals[:similarity] = options[:similarity].round
    else
      locals[:similarity] = nil
    end

    if options[:size]
      locals[:size] = post.file_size
    else
      locals[:size] = nil
    end

    if options[:stats]
      locals[:post] = post
      locals[:stats] = true
    else
      locals[:stats] = false
    end

    ApplicationController.render(partial: "posts/partials/index/preview", locals: locals)
  end

  def self.preview_class(post, highlight_score: nil, pool: nil, size: nil, similarity: nil, **options)
    klass = ["post-preview", "captioned"]
    # Always captioned with new post stats section.
    # klass << "captioned" if pool || size || similarity
    klass << "post-status-pending" if post.is_pending?
    klass << "post-status-flagged" if post.is_flagged?
    klass << "post-status-deleted" if post.is_deleted?
    klass << "post-status-has-parent" if post.parent_id
    klass << "post-status-has-children" if post.has_visible_children?
    klass << "post-pos-score" if highlight_score && post.score >= 3
    klass << "post-neg-score" if highlight_score && post.score <= -3
    klass << "post-rating-safe" if post.rating == 's'
    klass << "post-rating-questionable" if post.rating == 'q'
    klass << "post-rating-explicit" if post.rating == 'e'
    klass << "post-no-blacklist" if options[:no_blacklist]
    klass << "post-thumbnail-blacklisted" if options[:thumbnail_blacklisted]
    klass
  end

  def self.data_attributes(post)
    attributes = {
      "data-id" => post.id,
      "data-has-sound" => post.has_tag?('video_with_sound|flash_with_sound'),
      "data-tags" => post.tag_string,
      "data-pools" => post.pool_string,
      "data-approver-id" => post.approver_id,
      "data-rating" => post.rating,
      "data-width" => post.image_width,
      "data-height" => post.image_height,
      "data-flags" => post.status_flags,
      "data-parent-id" => post.parent_id,
      "data-has-children" => post.has_children?,
      "data-score" => post.score,
      "data-views" => post.view_count,
      "data-fav-count" => post.fav_count,
      "data-pixiv-id" => post.pixiv_id,
      "data-file-ext" => post.file_ext,
      "data-source" => post.source,
      "data-uploader-id" => post.uploader_id,
      "data-uploader" => post.uploader_name,
      "data-normalized-source" => post.normalized_source,
      "data-is-favorited" => post.favorited_by?(CurrentUser.user.id)
    }

    if post.visible?
      attributes["data-md5"] = post.md5
      attributes["data-file-url"] = post.file_url
      attributes["data-large-file-url"] = post.large_file_url
      attributes["data-preview-file-url"] = post.preview_file_url
    end

    attributes
  end

  def image_attributes
    attributes = {
        :id => "image",
        class: @post.display_class_for(CurrentUser.user),
        "data-original-width" => @post.image_width,
        "data-original-height" => @post.image_height,
        "data-large-width" => @post.large_image_width,
        "data-large-height" => @post.large_image_height,
        "data-tags" => @post.tag_string,
        :alt => humanized_essential_tag_string,
        "data-uploader" => @post.uploader_name,
        "data-rating" => @post.rating,
        "data-flags" => @post.status_flags,
        "data-parent-id" => @post.parent_id,
        "data-has-children" => @post.has_children?,
        "data-has-active-children" => @post.has_active_children?,
        "data-score" => @post.score,
        "data-fav-count" => @post.fav_count,
        "itemprop" => "contentUrl"
    }

    if @post.bg_color
      attributes['style'] = "background-color: ##{@post.bg_color};"
    end

    attributes
  end

  def initialize(post)
    @post = post
  end

  def tag_set_presenter
    @tag_set_presenter ||= TagSetPresenter.new(@post.tag_array)
  end

  def preview_html
    PostPresenter.preview(@post)
  end

  def humanized_tag_string
    @post.tag_string.split(/ /).slice(0, 25).join(", ").tr("_", " ")
  end

  def humanized_essential_tag_string
    @humanized_essential_tag_string ||= tag_set_presenter.humanized_essential_tag_string(default: "##{@post.id}")
  end

  def filename_for_download
    "#{humanized_essential_tag_string} - #{@post.md5}.#{@post.file_ext}"
  end

  def has_nav_links?(template)
    has_sequential_navigation?(template.params) || @post.pools.undeleted.any? || @post.post_sets.visible.any?
  end

  def has_sequential_navigation?(params)
    return false if Tag.has_metatag?(params[:q], :order, :ordfav, :ordpool)
    return false if params[:pool_id].present? || params[:post_set_id].present?
    true
  end

  def default_image_size(user, force_original)
    return "original" if @post.force_original_size?(force_original)
    return "fit" if user.default_image_size == "large" && !@post.allow_sample_resize?
    user.default_image_size
  end
end
