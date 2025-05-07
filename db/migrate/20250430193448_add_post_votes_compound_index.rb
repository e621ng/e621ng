# frozen_string_literal: true

class AddPostVotesCompoundIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :post_votes, %i[user_id created_at]
  end
end
