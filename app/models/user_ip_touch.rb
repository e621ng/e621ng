# frozen_string_literal: true

class UserIpTouch < ApplicationRecord
  SOURCES = %w[
    comment dmail blip post_flag post login
    artist_version note_version pool_version post_version wiki_page_version
  ].freeze

  belongs_to :user
  validates :ip_addr, :source, :last_seen_at, presence: true
  validates :source, inclusion: { in: SOURCES }

  def self.record_touches!(rows)
    return if rows.blank?
    upsert_all(
      rows,
      unique_by: :index_user_ip_touches_on_user_and_ip_and_source,
      on_duplicate: Arel.sql(<<~SQL.squish),
        hit_count = user_ip_touches.hit_count + EXCLUDED.hit_count,
        last_seen_at = GREATEST(user_ip_touches.last_seen_at, EXCLUDED.last_seen_at),
        updated_at = NOW()
      SQL
    )
  end
end
