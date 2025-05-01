# frozen_string_literal: true

class AddPostVotesCompondIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :post_votes, %i[user_id created_at], order: { user_id: :asc, created_at: :asc }
  end
end
