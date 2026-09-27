# frozen_string_literal: true

# Durable per-account copy of a subset of the user's localStorage-backed
# preferences. One row per user; `users.settings_revision` is bumped on every
# change so a normal page load can detect staleness without querying this table.
class UserSetting < ApplicationRecord
  self.primary_key = :user_id

  belongs_to :user

  # Keys the client may persist, and the primitive JSON type each accepts.
  # The actual option sets (theme names, logos, fonts, etc.) are a frontend
  # concern, not validated here -- these are presentation preferences, not
  # authorization or security state.
  ALLOWED_SETTINGS = {
    "theme_main" => :string,
    "theme_extra" => :string,
    "theme_palette" => :string,
    "theme_font" => :string,
    "theme_navbar" => :string,
    "theme_gestures" => :boolean,
    "theme_sticky_header" => :boolean,
    "theme_logo" => :string,
    "posts_wiki_excerpt" => :integer,
    "posts_sticky_search" => :boolean,
    "posts_autocomplete_cache" => :boolean,
    "posts_video_player" => :string,
    "site_events" => :boolean,
    "site_time_switch" => :boolean,
  }.freeze

  def self.valid_key?(key)
    ALLOWED_SETTINGS.key?(key.to_s)
  end

  def self.valid_value?(key, value)
    case ALLOWED_SETTINGS[key.to_s]
    when :boolean then [true, false].include?(value)
    when :string then value.is_a?(String)
    when :integer then value.is_a?(Integer)
    else false
    end
  end

  # Locks the user row first so concurrent writers (including the first
  # write, which creates this row) can't lose each other's change or race
  # the increment. An empty `changes` is a no-op.
  def self.apply_changes!(user, changes)
    return [user.settings_revision, find_by(user_id: user.id)&.settings || {}] if changes.blank?

    transaction do
      locked_user = User.lock.find(user.id)
      record = find_or_initialize_by(user_id: locked_user.id)
      record.settings = record.settings.merge(changes.stringify_keys)
      record.save!
      locked_user.update!(settings_revision: locked_user.settings_revision + 1)
      [locked_user.settings_revision, record.settings]
    end
  end
end
