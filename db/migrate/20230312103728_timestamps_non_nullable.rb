# frozen_string_literal: true

class TimestampsNonNullable < ActiveRecord::Migration[7.0]
  def change
    ApplicationRecord.without_timeout do
      non_null_timestamps(:api_keys)
      non_null_timestamps(:artist_versions)
      non_null_timestamps(:bulk_update_requests)
      non_null_timestamps(:comment_votes)
      non_null_timestamps(:dmail_filters)
      non_null_timestamps(:dmails)
      non_null_timestamps(:forum_topic_visits)
      non_null_timestamps(:forum_topics)
      non_null_timestamps(:ip_bans)
      non_null_timestamps(:mod_actions)
      non_null_timestamps(:news_updates)
      non_null_timestamps(:pool_versions)
      non_null_timestamps(:post_votes)
      non_null_timestamps(:uploads)
      non_null_timestamps(:user_feedback)
      non_null_timestamps(:user_name_change_requests)
      non_null_timestamps(:user_password_reset_nonces)
      change_column_null :users, :created_at, false
    end
  end

  def non_null_timestamps(table)
    change_column_null table, :created_at, false
    change_column_null table, :updated_at, false
  end
end
