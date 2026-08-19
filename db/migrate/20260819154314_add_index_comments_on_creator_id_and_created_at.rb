# frozen_string_literal: true

class AddIndexCommentsOnCreatorIdAndCreatedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_comments_on_creator_id_and_created_at"

  def up
    # Serves creator-filtered comment listings ordered by recency. Without it,
    # the planner walks index_comments_on_created_at_desc and filters by creator,
    # which times out for users whose comments are mostly old.
    Comment.without_timeout do
      add_index :comments,
                %i[creator_id created_at],
                order: { created_at: :desc },
                name: INDEX_NAME,
                algorithm: :concurrently
    end
  end

  def down
    remove_index :comments, name: INDEX_NAME, algorithm: :concurrently
  end
end
