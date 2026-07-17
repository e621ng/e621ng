# frozen_string_literal: true

class PostPresenter < Presenter
  attr_reader :pool

  delegate :inline_tag_list_html, to: :tag_set_presenter

  def initialize(post)
    super()
    @post = post
  end

  # CSS class applied to the media element for each initial size token.
  # The show-page media JS (Resizer.ts) uses the same mapping, so the server can
  # render the final class up-front and avoid an on-load reflow.
  INITIAL_SIZE_CLASSES = {
    "original" => "",
    "fit" => "fit-window",
    "fitv" => "fit-window-vertical",
    "large" => "fit-window",
  }.freeze

  def self.data_attributes(post)
    { data: post.thumbnail_attributes }
  end

  def image_attributes
    attributes = {
      :id => "image",
      class: initial_image_class(CurrentUser.user),
      :alt => humanized_essential_tag_string,
      "itemprop" => "contentUrl",
    }

    if @post.bg_color
      attributes["style"] = "background-color: ##{@post.bg_color};"
    end

    attributes
  end

  # Final CSS class for the initial render, matching the Resizer's mapping.
  def initial_image_class(user = CurrentUser.user)
    INITIAL_SIZE_CLASSES.fetch(default_image_size(user), "fit-window")
  end

  # Initial image URL, matching what the Resizer would pick for `default_image_size`.
  # "large" uses the JPG sample (WebP is offered via a <picture><source>);
  # everything else uses the original file.
  def initial_image_url(user = CurrentUser.user)
    default_image_size(user) == "large" ? @post.sample_url : @post.file_url
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
