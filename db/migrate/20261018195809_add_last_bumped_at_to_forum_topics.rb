# frozen_string_literal: true

class AddLastBumpedAtToForumTopics < ActiveRecord::Migration[8.1]
  def change
    add_column(:forum_topics, :last_bumped_at, :datetime)
    up_only { execute("UPDATE forum_topics SET last_bumped_at = updated_at") }
    change_column_null(:forum_topics, :last_bumped_at, false)
    add_index(:forum_topics, %i[is_sticky last_bumped_at])
    add_index(:forum_topics, :last_bumped_at)
  end
end
