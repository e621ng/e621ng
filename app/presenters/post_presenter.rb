# frozen_string_literal: true

class PostPresenter < Presenter
  attr_reader :pool

  delegate :inline_tag_list_html, to: :tag_set_presenter

  def initialize(post)
    super()
    @post = post
  end

  def self.data_attributes(post, include_post: false)
    attributes = post.thumbnail_attributes
    attributes[:post] = post_attribute_attribute(post).to_json if include_post
    { data: attributes }
  end

  def self.post_attribute_attribute(post)
    {
      id: post.id,
      created_at: post.created_at,
      updated_at: post.updated_at,
      fav_count: post.fav_count,
      comment_count: post.visible_comment_count(CurrentUser),
      change_seq: post.change_seq,
      uploader_id: post.uploader_id,
      description: post.description,
      flags: {
        pending: post.is_pending,
        flagged: post.is_flagged,
        note_locked: post.is_note_locked,
        status_locked: post.is_status_locked,
        rating_locked: post.is_rating_locked,
        deleted: post.is_deleted,
        has_notes: post.has_notes?,
      },
      score: {
        up: post.up_score,
        down: post.down_score,
        total: post.score,
      },
      relationships: {
        parent_id: post.parent_id,
        has_children: post.has_children,
        has_active_children: post.has_active_children,
        children: [],
      },
      pools: post.pool_ids,
      file: {
        width: post.image_width,
        height: post.image_height,
        ext: post.file_ext,
        size: post.file_size,
        md5: post.md5,
        url: post.visible? ? post.file_url : nil,
      },
      sample: {
        has: post.has_sample?,
        height: post.sample_height,
        width: post.sample_width,
        url: post.visible? ? post.sample_url : nil,
        alternates: post.video_sample_list,
      },
      sources: post.source&.split('\n'),
      tags: post.tag_string.split,
      locked_tags: post.locked_tags&.split || [],
      is_favorited: post.is_favorited?,
    }
  end

  def image_attributes
    attributes = {
      :id => "image",
      class: @post.display_class_for(CurrentUser.user),
      :alt => humanized_essential_tag_string,
      "itemprop" => "contentUrl",
    }

    if @post.bg_color
      attributes["style"] = "background-color: ##{@post.bg_color};"
    end

    attributes
  end

  def tag_set_presenter
    @tag_set_presenter ||= TagSetPresenter.new(@post.tag_array)
  end

  def humanized_tag_string
    @post.tag_string.split(/ /).slice(0, 25).join(", ").tr("_", " ")
  end

  def humanized_essential_tag_string
    strings = TagCategory::HUMANIZED_LIST.map do |category|
      mapping = TagCategory::HUMANIZED_MAPPING[category]
      max_tags = mapping["slice"]
      regexmap = mapping["regexmap"]
      formatstr = mapping["formatstr"]
      excluded_tags = mapping["exclusion"]

      type_tags = @post.tags_for_category(category).map(&:name) - excluded_tags
      next if type_tags.empty?

      if max_tags > 0 && type_tags.length > max_tags
        type_tags = type_tags.sort_by { |x| -x.size }.take(max_tags) + ["etc"]
      end

      if regexmap != //
        type_tags = type_tags.map { |tag| tag.match(regexmap)[1] }
      end

      if category == "copyright" && @post.tags_for_category("character").blank?
        type_tags.to_sentence
      else
        formatstr % type_tags.to_sentence
      end
    end

    strings = strings.compact.join(" ").tr("_", " ")
    @humanized_essential_tag_string ||= strings.presence || "##{@post.id}"
  end

  def filename_for_download
    "#{humanized_essential_tag_string} - #{@post.md5}.#{@post.file_ext}"
  end

  def has_nav_links?(template)
    has_sequential_navigation?(template.params) || @post.has_active_pools? || @post.post_sets.owned.any?
  end

  def has_sequential_navigation?(params)
    return false if TagQuery.has_metatag?(params[:q], "order")
    return false if params[:pool_id].present? || params[:post_set_id].present?
    true
  end

  def default_image_size(user)
    return "original" if @post.force_original_size?
    return "fit" if user.default_image_size == "large" && !@post.allow_sample_resize?
    user.default_image_size
  end

  def categorized_tag_list_text
    TagCategory::CATEGORIZED_LIST.map do |category|
      @post.tags_for_category(category).map(&:name).join(" ")
    end.compact_blank.join(" \n")
  end
end
