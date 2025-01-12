# frozen_string_literal: true

class ModAction < ApplicationRecord
  belongs_to :creator, class_name: "User"
  before_validation :initialize_creator, on: :create
  validates :creator_id, presence: true

  KnownActions = {
    artist_page_rename: %i[old_name new_name],
    artist_page_lock: %i[artist_page],
    artist_page_unlock: %i[artist_page],
    artist_user_linked: %i[artist_page user_id],
    artist_user_unlinked: %i[artist_page user_id],
    avoid_posting_create: %i[id artist_name],
    avoid_posting_update: %i[id artist_name details old_details staff_notes old_staff_notes],
    avoid_posting_delete: %i[id artist_name],
    avoid_posting_undelete: %i[id artist_name],
    avoid_posting_destroy: %i[id artist_name],
    staff_note_create: %i[id user_id body],
    staff_note_update: %i[id user_id body old_body],
    staff_note_delete: %i[id user_id],
    staff_note_undelete: %i[id user_id],
    blip_delete: %i[blip_id user_id],
    blip_hide: %i[blip_id user_id],
    blip_unhide: %i[blip_id user_id],
    blip_update: %i[blip_id user_id],
    comment_delete: %i[comment_id user_id],
    comment_hide: %i[comment_id user_id],
    comment_unhide: %i[comment_id user_id],
    comment_update: %i[comment_id user_id],
    forum_category_create: %i[forum_category_id],
    forum_category_delete: %i[forum_category_id],
    forum_category_update: %i[forum_category_id],
    forum_post_delete: %i[forum_post_id forum_topic_id user_id],
    forum_post_hide: %i[forum_post_id forum_topic_id user_id],
    forum_post_unhide: %i[forum_post_id forum_topic_id user_id],
    forum_post_update: %i[forum_post_id forum_topic_id user_id],
    forum_topic_delete: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_hide: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_unhide: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_lock: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_unlock: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_stick: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_unstick: %i[forum_topic_id forum_topic_title user_id],
    forum_topic_update: [], # FIXME: this key is never used anywhere
    help_create: %i[name wiki_page],
    help_delete: %i[name wiki_page],
    help_update: %i[name wiki_page],
    ip_ban_create: %i[ip_addr reason],
    ip_ban_delete: %i[ip_addr reason],
    mascot_create: %i[id],
    mascot_update: %i[id],
    mascot_delete: %i[id],
    pool_delete: %i[pool_id pool_name user_id],
    report_reason_create: %i[reason],
    report_reason_delete: %i[reason user_id],
    report_reason_update: %i[reason reason_was description description_was],
    set_update: %i[set_id user_id],
    set_delete: %i[set_id user_id],
    set_change_visibility: %i[set_id user_id is_public],
    tag_alias_create: %i[alias_id alias_desc],
    tag_alias_update: %i[alias_id alias_desc change_desc],
    tag_implication_create: %i[implication_id implication_desc],
    tag_implication_update: %i[implication_id implication_desc change_desc],
    ticket_claim: %i[ticket_id],
    ticket_unclaim: %i[ticket_id],
    ticket_update: %i[ticket_id],
    upload_whitelist_create: %i[pattern note hidden],
    upload_whitelist_update: %i[pattern note old_pattern hidden],
    upload_whitelist_delete: %i[pattern note hidden],
    user_blacklist_changed: %i[user_id],
    user_text_change: %i[user_id],
    user_upload_limit_change: %i[user_id old_upload_limit new_upload_limit],
    user_flags_change: %i[user_id added removed],
    user_level_change: %i[user_id level level_was],
    user_name_change: %i[user_id],
    user_delete: %i[user_id],
    user_ban: %i[user_id duration reason],
    user_ban_update: %i[user_id ban_id expires_at expires_at_was reason reason_was],
    user_unban: %i[user_id],
    user_feedback_create: %i[user_id reason type record_id],
    user_feedback_update: %i[user_id reason reason_was type type_was record_id],
    user_feedback_delete: %i[user_id reason reason_was type type_was record_id],
    user_feedback_undelete: %i[user_id reason reason_was type type_was record_id],
    user_feedback_destroy: %i[user_id reason type record_id],
    wiki_page_rename: %i[new_title old_title],
    wiki_page_delete: %i[wiki_page wiki_page_id],
    wiki_page_lock: %i[wiki_page],
    wiki_page_unlock: %i[wiki_page],

    mass_update: %i[antecedent consequent],
    nuke_tag: %i[tag_name],

    takedown_delete: %i[takedown_id],
    takedown_process: %i[takedown_id],
  }.freeze

  ProtectedActionKeys = %w[staff_note_create staff_note_update staff_note_delete staff_note_undelete ip_ban_create ip_ban_delete].freeze

  KnownActionKeys = KnownActions.keys.freeze

  module SearchMethods
    def visible(user)
      if user.is_staff?
        all
      else
        where.not(action: ProtectedActionKeys)
      end
    end

    def search(params)
      q = super

      q = q.where_user(:creator_id, :creator, params)

      if params[:action].present?
        q = q.where("action = ?", params[:action])
      end

      q.apply_basic_order(params)
    end
  end

  def can_view?(user)
    if user.is_staff?
      true
    else
      ProtectedActionKeys.exclude?(action)
    end
  end

  def values
    original_values = self[:values]

    if CurrentUser.is_admin?
      original_values
    else
      valid_keys = KnownActions[action.to_sym]&.map(&:to_s) || []
      sanitized_values = original_values.slice(*valid_keys)

      if %i[ip_ban_create ip_ban_delete].include?(action.to_sym)
        sanitized_values = sanitized_values.slice([])
      end

      if %i[upload_whitelist_create upload_whitelist_update upload_whitelist_delete].include?(action.to_sym)
        if sanitized_values["hidden"]
          sanitized_values = sanitized_values.slice("hidden")
        else
          sanitized_values = sanitized_values.slice("hidden", "note")
        end
      end

      sanitized_values
    end
  end

  def hidden_attributes
    super + %i[values values_old]
  end

  def method_attributes
    super + [:values]
  end

  def self.log(cat = :other, details = {})
    create(action: cat.to_s, values: details)
  end

  def initialize_creator
    self.creator_id = CurrentUser.id
  end

  extend SearchMethods
end
