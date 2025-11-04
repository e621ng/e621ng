# frozen_string_literal: true

class PostThumbnailComponent < ViewComponent::Base
  include IconHelper
  with_collection_parameter :post

  def initialize(post:, **options)
    super()

    # Post may be wrapped in a Draper decorator, get the underlying object
    @post = post.respond_to?(:object) ? post.object : post
    @options = options
    @user = defined?(CurrentUser) ? CurrentUser.user : nil

    if options[:pool].present?
      @pool = options[:pool]
      options[:stats] = false
    end
  end

  def render?
    return false if @post.nil?
    return false if hidden_deleted_post?
    return false if @post.loginblocked? || @post.safeblocked?
    true
  end

  private

  attr_reader :post, :user, :pool, :options

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
      class: preview_classes.join(" "),
      data: post.thumbnail_attributes.merge(border_states: border_state_count),
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

  def border_state_count
    count = 0
    count += 1 if post.has_visible_children?
    count += 1 if post.parent_id.present?
    count += 1 if post.is_pending?
    count += 1 if post.is_flagged?
    count
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
    @tooltip_text ||= begin
      tooltip = "Rating: #{@post.rating}\nID: #{@post.id}\nDate: #{@post.created_at}\nStatus: #{@post.status}\nScore: #{@post.score}"

      if @user.present? && @user.is_janitor?
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
    score = post.score
    return "0" if score.nil? || score == 0

    score = score.abs if score < 0
    return "#{(score / 1000.0).round(1)}k" if score >= 1000
    score.to_s
  end

  def score_icon
    return :square_slash if post.score.nil? || post.score == 0
    post.score > 0 ? :arrow_up_dash : :arrow_down_dash
  end

  def score_class
    return "neutral" if post.score.nil? || post.score == 0
    post.score > 0 ? "positive" : "negative"
  end

  ##############################
  ###  IQDB Results Section  ###
  ##############################

  def should_show_similarity?
    options[:similarity].present?
  end

  def similarity_post_info
    text = []
    text << number_to_human_size(@post.file_size)
    text << @post.file_ext.upcase
    text << "(#{@post.image_width}x#{@post.image_height})"
    text.join(" ")
  end

  ##############################
  #####  Pool Cover Page  ######
  ##############################

  def should_show_pool?
    options[:pool].present?
  end

  def pool_name
    options[:pool]&.pretty_name&.truncate(80)
  end
end
