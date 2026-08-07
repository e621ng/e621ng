# frozen_string_literal: true

class PostReplacementCardComponent < ViewComponent::Base
  include IconHelper
  include PostReplacementHelper
  with_collection_parameter :post_replacement

  # Highlighted-tag -> status icon, shown next to a pending replacement's status.
  STATUS_TAG_ICONS = {
    "avoid_posting" => :octagon_x,
    "conditional_dnp" => :octagon_alert,
    "better_version_at_source" => :diamond_plus,
  }.freeze

  # timeline: draw the status dot + rail affordance (index). false for ticket embeds.
  # expanded: override the open/closed default. nil => open iff pending or current.
  def initialize(post_replacement:, timeline: false, expanded: nil, actions: true)
    super()
    @replacement = post_replacement
    @timeline = timeline
    @expanded = expanded.nil? ? (post_replacement.is_pending? || post_replacement.is_current?) : expanded
    @actions = actions
    @user = CurrentUser.user
  end

  private

  attr_reader :replacement, :user, :actions

  delegate :post, to: :replacement

  ##############################
  ##########  Header  ##########
  ##############################

  def status_variant
    return "original" if replacement.is_backup?

    case replacement.status
    when "pending", "approved", "rejected", "promoted"
      replacement.status
    else
      "original"
    end
  end

  def card_classes
    classes = ["replacement-card"]

    classes << "is-#{status_variant}" if status_variant.present?
    classes << "is-current" if replacement.is_current?
    classes << "is-expanded" if @expanded
    classes << "has-timeline" if @timeline

    classes.join(" ")
  end

  def highlighted_tags
    return [] unless replacement.is_pending?

    post.tag_array & PostReplacement::HIGHLIGHTED_TAGS
  end

  def status_tag_icon(tag)
    STATUS_TAG_ICONS[tag]
  end

  ##############################
  ##########  Fields  ##########
  ##############################

  def created_at_label
    replacement.is_backup? ? "Backup created at" : "Created at"
  end

  # "WIDTHxHEIGHT ext (size, DURATIONs)" for either the replacement or the post.
  # Replacements don't store a duration; the post's only describes a replacement's
  # file when that replacement is current, so it's omitted otherwise.
  def file_details(record)
    details = "#{record.image_width}x#{record.image_height} #{record.file_ext} "
    details += "(#{record.file_size.to_fs(:human_size, precision: 5)}"
    details += ", #{post.duration}s" if record.is_video? && (record == post || replacement.is_current?)
    "#{details})"
  end

  def show_status_changed_at?
    replacement.updated_at != replacement.created_at
  end

  def sources
    return [] if replacement.source.blank?

    replacement.source_list.partition { |s| !s.start_with?("-") }.flatten
  end

  def show_previous_uploader?
    !replacement.is_backup? && !replacement.is_pending? && replacement.uploader_on_approve.present?
  end

  def show_penalize_toggle?
    show_staff_actions? && replacement.is_approved?
  end

  ##############################
  #########  Actions  ##########
  ##############################

  def show_staff_actions?
    user&.can_approve_posts?
  end

  def show_admin_actions?
    user&.is_admin?
  end

  def show_approve?
    show_staff_actions? && replacement.is_pending? && !post.is_deleted?
  end

  def show_reject?
    show_staff_actions? && replacement.is_pending?
  end

  def show_compare?
    show_staff_actions? && replacement.is_pending?
  end

  # Approving with penalize=false is the "Reset To" action; approve penalizes the
  # current uploader only when it differs from this replacement's creator.
  def approve_penalizes?
    post.uploader != replacement.creator
  end

  def show_promote?
    show_staff_actions? && !replacement.is_current? && !replacement.is_promoted? && !replacement.is_backup?
  end

  def show_reset_to?
    show_staff_actions? && !replacement.is_current? && !replacement.is_promoted? && !replacement.is_pending? && !post.is_deleted?
  end

  # Transferring off a deleted source post is allowed, so this is not gated on the post's
  # deletion state; the model only guards the destination.
  def show_transfer?
    show_staff_actions? && (replacement.is_pending? || replacement.is_rejected?)
  end
end
