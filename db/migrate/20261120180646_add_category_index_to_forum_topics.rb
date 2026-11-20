# frozen_string_literal: true

class AddCategoryIndexToForumTopics < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_forum_topics_on_category_sticky_bumped"

  def up
    # Serves the per-category latest-topics lookup on /forums (doc 46) and the
    # category filter on /forum_topics, neither of which had a usable index.
    ForumTopic.without_timeout do
      add_index :forum_topics,
                %i[category_id is_sticky last_bumped_at],
                name: INDEX_NAME,
                algorithm: :concurrently
    end
  end

  def down
    remove_index :forum_topics, name: INDEX_NAME, algorithm: :concurrently
  end
end
