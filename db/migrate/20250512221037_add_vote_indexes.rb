# frozen_string_literal: true

class AddVoteIndexes < ActiveRecord::Migration[7.1]
  def change
    PostVote.without_timeout do
      add_index :post_votes, %i[user_id id]
    end
    CommentVote.without_timeout do
      add_index :comment_votes, %i[user_id id]
    end
  end
end
