# frozen_string_literal: true

class CreateForumTopicStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :forum_topic_statuses do |t|
      t.references :user, null: false
      t.references :forum_topic, null: false
      t.datetime :subscription_last_read_at
      t.boolean :subscription, null: false, default: false
      t.boolean :mute, null: false, default: false
      t.timestamps
    end
  end
end
