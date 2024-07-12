# frozen_string_literal: true

class AddForumPostsTagChangeRequest < ActiveRecord::Migration[7.0]
  def change
    add_column :forum_posts, :tag_change_request_id, :bigint
    add_column :forum_posts, :tag_change_request_type, :string
  end
end
