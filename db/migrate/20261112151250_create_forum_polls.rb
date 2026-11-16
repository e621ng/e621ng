# frozen_string_literal: true

class CreateForumPolls < ActiveRecord::Migration[8.1]
  def change
    create_table :forum_polls do |t|
      t.references :forum_topic, null: false, foreign_key: true, type: :integer, index: { unique: true }
      t.references :creator, null: false, foreign_key: { to_table: :users }, type: :integer, index: false
      t.integer :max_choices, null: false, default: 1
      t.datetime :expires_at, null: false
      t.references :closed_early_by, foreign_key: { to_table: :users }, type: :integer, index: false
      t.integer :voter_count, null: false, default: 0
      t.timestamps
    end

    # Options carry no timestamps: they are frozen once anyone has voted and the poll has its own.
    create_table :forum_poll_options do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :forum_poll, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.text :body, null: false
      t.integer :vote_count, null: false, default: 0
      # Not unique: positions are reassigned server-side and nested-attribute edits save rows one at a time.
      t.index %i[forum_poll_id position]
    end

    # Votes are immutable rows, so there is no updated_at.
    create_table :forum_poll_votes do |t|
      t.references :forum_poll, null: false, foreign_key: true, index: false
      t.references :forum_poll_option, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, type: :integer, index: false
      t.inet :user_ip_addr
      t.datetime :created_at, null: false
      t.index %i[forum_poll_option_id user_id], unique: true
      t.index %i[forum_poll_id user_id]
      t.index %i[user_id created_at]
    end
  end
end
