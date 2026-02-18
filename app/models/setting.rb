# frozen_string_literal: true

# TODO: Stop the `state == "1"` check downstream; should already normalize it accordingly.
# See [here](https://github.com/huacnlee/rails-settings-cached?tab=readme-ov-file#usage).
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  module RailsSettings
    module Fields
      class EnumField < ::RailsSettings::Fields::Base
        attr_reader :map, :inverted

        def initialize(*, options:, **, &)
          raise ArgumentError, "Must provide a Hash for 'options[:map]'." unless options.is_a?(Hash) && options[:map].is_a?(Hash)
          default_proc = ->(hash, key) do
            begin
              hash[EnumField.coerce(key, throw_on_failure: true) { |v| hash.include?(v) }]
            rescue ArgumentError
              raise ArgumentError, "Invalid value; No '#{key}' key in hash.\n#{hash}"
            end
          end
          @map = options[:map]
          @map.default_proc = default_proc unless @map.frozen? || @map.default_proc || @map.default
          @map.freeze
          @inverted = @map.invert
          # `invert` doesn't copy the default, & we want to do this in case map's default_proc wasn't set by us.
          @inverted.default_proc = default_proc
          @inverted.freeze
          super
        end

        def serialize(value)
          map[value]
        end

        def deserialize(value)
          inverted[value]
        end

        # Attempts to coerce the given value into an equivalent form that might pass the condition.
        # ### Parameters
        # #### Block
        # ### Returns
        def self.coerce(key, throw_on_failure: false, &)
          case key.class
          when String
            return key.to_sym if yield key.to_sym
            if /\A\s*[\-\+]?[0-9]/.match?(key)
              t = key.to_f
              return t if yield t
              t = t.to_i
              return t if yield t
            end
          when Float
            return key.to_s if yield key.to_s
            return key.to_sym if yield key.to_sym
            t = key.to_i
            return t if yield t
            t = key.to_s
            return t if yield t
            t = key.to_sym
            return t if yield t
          when Integer
            return key.to_s if yield key.to_s
            return key.to_sym if yield key.to_sym
            t = key.to_f
            return t if yield t
            t = key.to_s
            return t if yield t
            t = key.to_sym
            return t if yield t
          when Symbol
            t = key.to_s
            return t if yield t
            if /\A\s*[\-\+]?[0-9]/.match?(t)
              t = t.to_f
              return t if yield t
              t = t.to_i
              return t if yield t
            end
          else
            t = key.to_s
            return t if yield t
            t = t.to_sym
            return t if yield t
          end
          raise ArgumentError, "Invalid value of '#{key}'" if throw_on_failure
        end

        def self.static_deserialize(key, map)
          inverted = map.invert
          # `invert` doesn't copy the default
          inverted.default_proc = ->(hash, k) do
            begin
              hash[EnumField.coerce(k, throw_on_failure: true) { |v| hash.include?(v) }]
            rescue ArgumentError
              raise ArgumentError, "Invalid value; No '#{k}' key in hash.\n#{hash}"
            end
          end
          inverted[key]
        end
      end
    end
  end

  scope :lockdown do
    field :uploads_disabled,    type: :boolean, default: false
    field :pools_disabled,      type: :boolean, default: false
    field :post_sets_disabled,  type: :boolean, default: false
    field :comments_disabled,   type: :boolean, default: false
    field :forums_disabled,     type: :boolean, default: false
    field :blips_disabled,      type: :boolean, default: false
    field :aiburs_disabled,     type: :boolean, default: false
    field :favorites_disabled,  type: :boolean, default: false
    field :votes_disabled,      type: :boolean, default: false
  end

  scope :limits do
    field :uploads_min_level,       type: :integer, default: User::Levels::MEMBER, validates: { presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
    field :hide_pending_posts_for,  type: :integer, default: 0, validates: { presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
  end

  scope :tos do
    field :tos_version, type: :numeric, default: 1, validates: { presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
  end

  scope :maintenance do
    field :disable_exception_prune, type: :boolean, default: true
  end

  scope :general do
    unless Danbooru.config.use_settings_for?(:flag_reason_visibility)
      # Determines who the flag reasons are visible to.
      def self.flag_reason_visibility
        Danbooru.config.flag_reason_visibility
      end

      def self.flag_reason_visibility=(_)
        raise SyntaxError, "Using config file; cannot assign"
      end
      next
    end

    # Determines if flag reasons will be shown to everyone, or just the creator & staff.
    # field :flag_reason_visibility, type: :enum_field, map: { staff: 0, uploader: 1, users: 2, all: 3 }, default: :staff
    field :flag_reason_visibility, type: :enum_field, map: PostFlag::FLAG_REASON_VISIBILITY_LEVEL_MAP, default: :staff
  end
  GENERAL_SETTINGS = (Setting.defined_fields.group_by { |k, _v| k[:scope] }[:general]&.pluck(:key) || []).freeze

  def self.deserialize_boolean(state)
    state == "1"
  end
end
