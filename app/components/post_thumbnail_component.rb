# frozen_string_literal: true

class PostThumbnailComponent < ViewComponent::Base
  with_collection_parameter :post

  def initialize(post:, **options)
    super()
    # Post may be wrapped in a Draper decorator, get the underlying object
    @post = post.respond_to?(:object) ? post.object : post
    @options = options
    @user = defined?(CurrentUser) ? CurrentUser : nil
  end

  def render?
    return false if @post.nil?
    return false if hidden_deleted_post?
    return false if @post.loginblocked? || @post.safeblocked?
    true
  end

  private

  attr_reader :post, :options

  def hidden_deleted_post?
    !options[:show_deleted] &&
      @post.is_deleted? &&
      TagQuery.should_hide_deleted_posts?(options[:tags], at_any_level: true)
  end

  def should_render_image?
    !@post.is_deleted? || @user&.is_janitor? || @user&.can_approve_posts?
  end

  ##############################
  ####  Article Attributes  ####
  ##############################

  def article_attributes
    {
      id: "post_#{post.id}",
      class: preview_classes.join(" "),
      data: post.thumbnail_attributes,
    }
  end

  def preview_classes
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
    klass << "no-stats" unless should_show_stats?
    klass
  end

  ##############################
  #######  Link & Image  #######
  ##############################

  def link_target
    options[:link_target] || post
  end

  def link_params
    params = {}
    params["q"] = options[:tags] if options[:tags].present?
    params["pool_id"] = options[:pool_id] if options[:pool_id]
    params["post_set_id"] = options[:post_set_id] if options[:post_set_id]
    params
  end

  def tooltip_text
    tooltip = "Rating: #{@post.rating}\nID: #{@post.id}\nDate: #{@post.created_at}\nStatus: #{@post.status}\nScore: #{@post.score}"

    if defined?(CurrentUser) && CurrentUser.is_janitor?
      tooltip += "\nUploader: #{@post.uploader_name}"
      if @post.is_flagged? || @post.is_deleted?
        flag = @post.flags.order(id: :desc).first
        tooltip += "\nFlag Reason: #{flag&.reason}" if @post.is_flagged?
        tooltip += "\nDel Reason: #{flag&.reason}" if @post.is_deleted?
      end
    end

    tooltip += "\n\n#{@post.tag_string}"
    tooltip
  end

  def preview_urls
    @preview_urls ||= post.preview_file_url_pair
  end

  def alt_text
    "post ##{post.id}"
  end

  def webp_enabled?
    Danbooru.config.webp_previews_enabled?
  end

  ##############################
  ####  Post Stat Section  #####
  ##############################

  def should_show_stats?
    @should_show_stats ||= options.fetch(:stats) { @user&.show_post_statistics? }
  end

  def shortened_score
    case post.score
    when nil
      "0"
    when (..-1)
      post.score.abs.to_s
    when (1000..)
      "#{(post.score / 1000.0).round(1)}k"
    else
      post.score.to_s
    end
  end

  def score_icon
    return :square_slash if post.score == 0
    post.score > 0 ? :arrow_up_dash : :arrow_down_dash
  end

  def score_class
    return "neutral" if post.score == 0
    post.score > 0 ? "positive" : "negative"
  end
end
