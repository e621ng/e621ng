# frozen_string_literal: true

class UpdateCommentVoteIdToBigint < ActiveRecord::Migration[8.1]
  def change
    change_column :comment_votes, :id, :bigint
  end
end
