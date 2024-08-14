# frozen_string_literal: true

class CreateUserBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table(:user_blocks) do |t|
      t.references(:user, foreign_key: true, null: false)
      t.references(:target, foreign_key: { to_table: :users }, null: false)
      t.boolean(:hide_blips, default: false, null: false)
      t.boolean(:hide_comments, default: false, null: false)
      t.boolean(:hide_forum_topics, default: false, null: false)
      t.boolean(:hide_forum_posts, default: false, null: false)
      t.boolean(:disable_messages, default: false, null: false)
      t.timestamps
    end
  end
end
