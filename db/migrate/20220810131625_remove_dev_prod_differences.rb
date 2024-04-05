# frozen_string_literal: true

class RemoveDevProdDifferences < ActiveRecord::Migration[6.1]
  def change
    execute "DROP FUNCTION IF EXISTS sourcepattern";

    non_null_timestamps(:artist_urls)
    non_null_timestamps(:artists)
    non_null_timestamps(:bans)
    non_null_timestamps(:comments)
    non_null_timestamps(:forum_posts)
    non_null_timestamps(:note_versions)
    non_null_timestamps(:notes)
    non_null_timestamps(:pools)
    non_null_timestamps(:wiki_page_versions)
    non_null_timestamps(:wiki_pages)

    change_column_null :bans, :user_id, false

    change_column_null :forum_topics, :creator_ip_addr, false

    change_column_default :note_versions, :version, nil

    change_column_null :pools, :name, false

    change_column_null :post_versions, :updater_ip_addr, false

    change_column_null :posts, :has_active_children, false
    change_column_null :posts, :created_at, false
    change_column_default :posts, :source, nil

    change_column :tags, :category, :smallint

    change_column_null :post_sets, :description, false

    change_column_default :users, :per_page, 75
    change_column_default :users, :comment_threshold, -2

    change_column_null :post_flags, :created_at, false
  end

  def non_null_timestamps(table)
    change_column_null table, :created_at, false
    change_column_null table, :updated_at, false
  end
end
