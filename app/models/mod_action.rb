# frozen_string_literal: true

class ModAction < ApplicationRecord
  belongs_to :creator, :class_name => "User"
  before_validation :initialize_creator, :on => :create
  validates :creator_id, presence: true

  KnownActions = [
      :artist_page_rename,
      :artist_page_lock,
      :artist_page_unlock,
      :artist_user_linked,
      :artist_user_unlinked,
      :avoid_posting_create,
      :avoid_posting_update,
      :avoid_posting_delete,
      :avoid_posting_undelete,
      :avoid_posting_destroy,
      :blip_delete,
      :blip_hide,
      :blip_unhide,
      :blip_update,
      :comment_delete,
      :comment_hide,
      :comment_unhide,
      :comment_update,
      :forum_category_create,
      :forum_category_delete,
      :forum_category_update,
      :forum_post_delete,
      :forum_post_hide,
      :forum_post_unhide,
      :forum_post_update,
      :forum_topic_delete,
      :forum_topic_hide,
      :forum_topic_unhide,
      :forum_topic_lock,
      :forum_topic_unlock,
      :forum_topic_stick,
      :forum_topic_unstick,
      :forum_topic_update,
      :help_create,
      :help_delete,
      :help_update,
      :ip_ban_create,
      :ip_ban_delete,
      :mascot_create,
      :mascot_update,
      :mascot_delete,
      :pool_delete,
      :report_reason_create,
      :report_reason_delete,
      :report_reason_update,
      :set_update,
      :set_delete,
      :set_change_visibility,
      :tag_alias_create,
      :tag_alias_update,
      :tag_implication_create,
      :tag_implication_update,
      :ticket_claim,
      :ticket_unclaim,
      :ticket_update,
      :upload_whitelist_create,
      :upload_whitelist_update,
      :upload_whitelist_delete,
      :user_blacklist_changed,
      :user_text_change,
      :user_upload_limit_change,
      :user_flags_change,
      :user_level_change,
      :user_name_change,
      :user_delete,
      :user_ban,
      :user_ban_update,
      :user_unban,
      :user_feedback_create,
      :user_feedback_update,
      :user_feedback_delete,
      :user_feedback_undelete,
      :user_feedback_destroy,
      :wiki_page_rename,
      :wiki_page_delete,
      :wiki_page_lock,
      :wiki_page_unlock,

      :mass_update,
      :nuke_tag,

      :takedown_delete,
      :takedown_process,
  ]

  def self.search(params)
    q = super

    q = q.where_user(:creator_id, :creator, params)

    if params[:action].present?
      q = q.where('action = ?', params[:action])
    end

    q.apply_basic_order(params)
  end

  def hidden_attributes
    super + [:values]
  end

  def self.log(cat = :other, details = {})
    create(action: cat.to_s, values: details)
  end

  def initialize_creator
    self.creator_id = CurrentUser.id
  end
end
