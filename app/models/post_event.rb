# frozen_string_literal: true

class PostEvent < ApplicationRecord
  belongs_to :creator, class_name: "User"
  enum :action, {
    deleted: 0,
    undeleted: 1,
    approved: 2,
    unapproved: 3,
    flag_created: 4,
    flag_removed: 5,
    favorites_moved: 6,
    favorites_received: 7,
    rating_locked: 8,
    rating_unlocked: 9,
    status_locked: 10,
    status_unlocked: 11,
    note_locked: 12,
    note_unlocked: 13,
    comment_locked: 18,
    comment_unlocked: 19,
    comment_disabled: 22,
    comment_enabled: 23,
    replacement_accepted: 14,
    replacement_rejected: 15,
    replacement_promoted: 20,
    replacement_deleted: 16,
    expunged: 17,
    changed_bg_color: 21,
    replacement_penalty_changed: 24,
    owner_changed: 25,
    replacement_moved: 26,
  }
  MOD_ONLY_SEARCH_ACTIONS = %w[comment_locked comment_unlocked comment_disabled comment_enabled].freeze

  KnownActions = { # rubocop:disable Naming/ConstantName
    deleted: { reason: :string },
    undeleted: {},
    approved: {},
    unapproved: {},
    flag_created: { reason: :string },
    flag_removed: {},
    favorites_moved: { parent_id: :integer },
    favorites_received: { child_id: :integer },
    rating_locked: {},
    rating_unlocked: {},
    status_locked: {},
    status_unlocked: {},
    note_locked: {},
    note_unlocked: {},
    comment_locked: {},
    comment_unlocked: {},
    comment_disabled: {},
    comment_enabled: {},
    replacement_accepted: { replacement_id: :integer, old_md5: :string, new_md5: :string },
    replacement_rejected: { replacement_id: :integer },
    replacement_promoted: { source_post_id: :integer },
    replacement_deleted: { replacement_id: :integer, md5: :string, storage_id: :string },
    expunged: {},
    changed_bg_color: { bg_color: :string },
    replacement_penalty_changed: { replacement_id: :integer, penalize: :boolean },
    owner_changed: { old_owner: :integer, new_owner: :integer },
    replacement_moved: { replacement_id: :integer, old_post: :integer, new_post: :integer },
  }.freeze

  KnownActionKeys = KnownActions.keys.freeze
  ProtectedActionKeys = %w[replacement_penalty_changed].freeze

  def self.add(post_id, creator, action, data = {})
    create!(post_id: post_id, creator: creator, action: action.to_s, extra_data: data)
  end

  def is_creator_visible?(user)
    case action
    when "flag_created"
      user.can_view_flagger?(creator_id)
    else
      true
    end
  end

  def extra_data
    original_data = self[:extra_data] || {}
    return {} unless original_data.is_a?(Hash)
    return original_data if CurrentUser.is_admin?

    valid_keys = KnownActions[action.to_sym]&.keys&.map(&:to_s) || []
    sanitized_values = original_data.slice(*valid_keys)

    if %w[replacement_deleted].include?(action)
      sanitized_values = sanitized_values.except("storage_id")
    end

    sanitized_values
  end

  module SearchMethods
    def visible(user)
      return all if user.is_staff?
      where.not(action: ProtectedActionKeys)
    end

    def jsonb_boolean_attribute_matches(attribute, value)
      bool_value = ActiveRecord::Type::Boolean.new.cast(value)

      case bool_value
      when true
        where(Arel.sql("(extra_data ->> '#{attribute}')::BOOLEAN IS TRUE"))
      when false
        where(Arel.sql("(extra_data ->> '#{attribute}')::BOOLEAN IS FALSE"))
      else
        raise ArgumentError, "Value must be truthy or falsy"
      end
    end

    def jsonb_numeric_attribute_matches(attribute, range)
      qualified_column = Arel.sql("extra_data ->> '#{attribute}'")
      parsed_range = ParseValue.range(range, :integer)

      add_range_relation(parsed_range, qualified_column)
    end

    def jsonb_text_attribute_matches(attribute, value, convert_to_wildcard: false)
      qualified_column = Arel.sql("extra_data ->> '#{attribute}'")
      value = "*#{value}*" if convert_to_wildcard && value.exclude?("*")

      if value.include?("*")
        where("lower(#{qualified_column}) LIKE :value ESCAPE E'\\\\'", value: value.downcase.to_escaped_for_sql_like)
      else
        where("to_tsvector(:ts_config, #{qualified_column}) @@ plainto_tsquery(:ts_config, :value)", ts_config: "english", value: value)
      end
    end

    def search(params)
      q = super

      q = q.attribute_matches(:post_id, params[:post_id])

      q = q.where_user(:creator_id, :creator, params) do |condition, user_ids|
        condition.where.not(
          action: actions[:flag_created],
          creator_id: user_ids.reject { |user_id| CurrentUser.can_view_flagger?(user_id) },
        )
      end

      if params[:action].present? && KnownActionKeys.include?(params[:action].to_sym)
        if !CurrentUser.user.is_moderator? && MOD_ONLY_SEARCH_ACTIONS.include?(params[:action])
          raise(User::PrivilegeError)
        end
        q = q.where(action: params[:action])

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

    def search_options_for(user)
      options = actions.keys.map(&:to_s)
      options -= MOD_ONLY_SEARCH_ACTIONS unless user.is_moderator?
      options -= ProtectedActionKeys unless user.is_staff?
      options
    end
  end

  extend(SearchMethods)
end
