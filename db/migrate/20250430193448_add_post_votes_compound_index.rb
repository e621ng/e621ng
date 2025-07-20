# frozen_string_literal: true

class AddPostVotesCompoundIndex < ActiveRecord::Migration[7.1]
  def change
    PostVote.without_timeout do
      add_index :post_votes, %i[user_id created_at]
    end
  end
end
