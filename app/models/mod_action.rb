# frozen_string_literal: true

class ModAction < ApplicationRecord
  belongs_to :creator, class_name: "User"
  before_validation :initialize_creator, on: :create
  validates :creator_id, presence: true

  KnownActions = {
    artist_page_rename: { old_name: :string, new_name: :string },
    artist_page_lock: { artist_page: :string },
    artist_page_unlock: { artist_page: :string },
    artist_user_linked: { artist_page: :string, user_id: :integer },
    artist_user_unlinked: { artist_page: :string, user_id: :integer },
    avoid_posting_create: { id: :integer, artist_name: :string },
    avoid_posting_update: { id: :integer, artist_name: :string, details: :string, old_details: :string, staff_notes: :string, old_staff_notes: :string },
    avoid_posting_delete: { id: :integer, artist_name: :string },
    avoid_posting_undelete: { id: :integer, artist_name: :string },
    avoid_posting_destroy: { id: :integer, artist_name: :string },
    staff_note_create: { id: :integer, user_id: :integer, body: :string },
    staff_note_update: { id: :integer, user_id: :integer, body: :string, old_body: :string },
    staff_note_delete: { id: :integer, user_id: :integer },
    staff_note_undelete: { id: :integer, user_id: :integer },
    blip_delete: { blip_id: :integer, user_id: :integer },
    blip_hide: { blip_id: :integer, user_id: :integer },
    blip_unhide: { blip_id: :integer, user_id: :integer },
    blip_update: { blip_id: :integer, user_id: :integer },
    comment_delete: { comment_id: :integer, user_id: :integer },
    comment_hide: { comment_id: :integer, user_id: :integer },
    comment_unhide: { comment_id: :integer, user_id: :integer },
    comment_update: { comment_id: :integer, user_id: :integer },
    forum_category_create: { forum_category_id: :integer },
    forum_category_delete: { forum_category_id: :integer },
    forum_category_update: { forum_category_id: :integer },
    forum_post_delete: { forum_post_id: :integer, forum_topic_id: :integer, user_id: :integer },
    forum_post_hide: { forum_post_id: :integer, forum_topic_id: :integer, user_id: :integer },
    forum_post_unhide: { forum_post_id: :integer, forum_topic_id: :integer, user_id: :integer },
    forum_post_update: { forum_post_id: :integer, forum_topic_id: :integer, user_id: :integer },
    forum_topic_delete: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_hide: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_unhide: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_lock: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_unlock: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_stick: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_unstick: { forum_topic_id: :integer, forum_topic_title: :string, user_id: :integer },
    forum_topic_update: {}, # FIXME: this key is never used anywhere
    help_create: { name: :string, wiki_page: :string },
    help_delete: { name: :string, wiki_page: :string },
    help_update: { name: :string, wiki_page: :string },
    ip_ban_create: { ip_addr: :string, reason: :string },
    ip_ban_delete: { ip_addr: :string, reason: :string },
    mascot_create: { id: :integer },
    mascot_update: { id: :integer },
    mascot_delete: { id: :integer },
    pool_delete: { pool_id: :integer, pool_name: :string, user_id: :integer },
    report_reason_create: { reason: :string },
    report_reason_delete: { reason: :string, user_id: :integer },
    report_reason_update: { reason: :string, reason_was: :string, description: :string, description_was: :string },
    set_update: { set_id: :integer, user_id: :integer },
    set_delete: { set_id: :integer, user_id: :integer },
    set_change_visibility: { set_id: :integer, user_id: :integer, is_public: :boolean },
    tag_destroy: { name: :string },
    tag_alias_create: { alias_id: :integer, alias_desc: :string },
    tag_alias_update: { alias_id: :integer, alias_desc: :string, change_desc: :string },
    tag_implication_create: { implication_id: :integer, implication_desc: :string },
    tag_implication_update: { implication_id: :integer, implication_desc: :string, change_desc: :string },
    ticket_claim: { ticket_id: :integer },
    ticket_unclaim: { ticket_id: :integer },
    ticket_update: { ticket_id: :integer, status: :string, response: :string, status_was: :string, response_was: :string },
    upload_whitelist_create: { pattern: :string, note: :string, hidden: :boolean },
    upload_whitelist_update: { pattern: :string, note: :string, old_pattern: :string, hidden: :boolean },
    upload_whitelist_delete: { pattern: :string, note: :string, hidden: :boolean },
    user_blacklist_changed: { user_id: :integer },
    user_text_change: { user_id: :integer },
    user_upload_limit_change: { user_id: :integer, old_upload_limit: :integer, new_upload_limit: :integer },
    user_uploads_toggle: { user_id: :integer, disabled: :boolean },
    user_flags_change: { user_id: :integer, added: :string, removed: :string },
    user_level_change: { user_id: :integer, level: :string, level_was: :string },
    user_name_change: { user_id: :integer },
    user_delete: { user_id: :integer },
    user_ban: { user_id: :integer, duration: :integer, reason: :string },
    user_ban_update: { user_id: :integer, ban_id: :integer, expires_at: :datetime, expires_at_was: :datetime, reason: :string, reason_was: :string },
    user_unban: { user_id: :integer },
    user_feedback_create: { user_id: :integer, reason: :string, type: :string, record_id: :integer },
    user_feedback_update: { user_id: :integer, reason: :string, reason_was: :string, type: :string, type_was: :string, record_id: :integer },
    user_feedback_delete: { user_id: :integer, reason: :string, reason_was: :string, type: :string, type_was: :string, record_id: :integer },
    user_feedback_undelete: { user_id: :integer, reason: :string, reason_was: :string, type: :string, type_was: :string, record_id: :integer },
    user_feedback_destroy: { user_id: :integer, reason: :string, type: :string, record_id: :integer },
    user_flush_favorites: { user_id: :integer },
    wiki_page_rename: { new_title: :string, old_title: :string },
    wiki_page_delete: { wiki_page: :string, wiki_page_id: :integer },
    wiki_page_lock: { wiki_page: :string },
    wiki_page_unlock: { wiki_page: :string },
    mass_update: { antecedent: :string, consequent: :string },
    nuke_tag: { tag_name: :string },
    takedown_delete: { takedown_id: :integer },
    takedown_process: { takedown_id: :integer },
    post_version_hide: { version: :integer, post_id: :integer },
    post_version_unhide: { version: :integer, post_id: :integer },
  }.freeze

  ProtectedActionKeys = %w[staff_note_create staff_note_update staff_note_delete staff_note_undelete ip_ban_create ip_ban_delete post_version_hide post_version_unhide].freeze

  KnownActionKeys = KnownActions.keys.freeze

  def self.available_action_keys(user = CurrentUser)
    return KnownActionKeys if user.is_staff?

    KnownActionKeys - ProtectedActionKeys.map(&:to_sym)
  end

  module SearchMethods
    def visible(user)
      if user.is_staff?
        all
      else
        where.not(action: ProtectedActionKeys)
      end
    end

    def jsonb_boolean_attribute_matches(attribute, value)
      bool_value = ActiveRecord::Type::Boolean.new.cast(value)

      case bool_value
      when true
        where(Arel.sql("(values ->> '#{attribute}')::BOOLEAN IS TRUE"))
      when false
        where(Arel.sql("(values ->> '#{attribute}')::BOOLEAN IS FALSE"))
      else
        raise ArgumentError, "Value must be truthy or falsy"
      end
    end

    def jsonb_numeric_attribute_matches(attribute, range)
      qualified_column = Arel.sql("(values ->> '#{attribute}')::INTEGER")
      parsed_range = ParseValue.range(range, :integer)

      add_range_relation(parsed_range, qualified_column)
    end

    def jsonb_text_attribute_matches(attribute, value, convert_to_wildcard: false)
      qualified_column = Arel.sql("values ->> '#{attribute}'")
      value = "*#{value}*" if convert_to_wildcard && value.exclude?("*")

      if value.include?("*")
        where("lower(#{qualified_column}) LIKE :value ESCAPE E'\\\\'", value: value.downcase.to_escaped_for_sql_like)
      else
        where("to_tsvector(:ts_config, #{qualified_column}) @@ plainto_tsquery(:ts_config, :value)", ts_config: "english", value: value)
      end
    end

    def search(params)
      params ||= {}
      q = super
      q = q.where_user(:creator_id, :creator, params)
      q = q.where(action: params[:action]) if params[:action].present?

      if params[:action].present? && KnownActions.key?(params[:action].to_sym)
        field_types = KnownActions[params[:action].to_sym]
        valid_params = params.slice(*field_types.keys.map(&:to_s))

        field_types.each do |key, type|
          next if valid_params[key.to_s].blank?

          case type
          when :integer, :datetime
            q = q.jsonb_numeric_attribute_matches(key, valid_params[key.to_s])
          when :boolean
            q = q.jsonb_boolean_attribute_matches(key, valid_params[key.to_s])
          when :string
            if valid_params[key.to_s].include?("*")
              q = q.jsonb_text_attribute_matches(key, valid_params[key.to_s], convert_to_wildcard: true)
            else
              q = q.jsonb_text_attribute_matches(key, valid_params[key.to_s])
            end
          end
        end
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
      valid_keys = KnownActions[action.to_sym]&.keys&.map(&:to_s) || []
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

      if !CurrentUser.is_moderator? && %i[ticket_update].include?(action.to_sym)
        sanitized_values = sanitized_values.slice("ticket_id")
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
