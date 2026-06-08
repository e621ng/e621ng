# frozen_string_literal: true

class UpdateCommentVoteIdToBigint < ActiveRecord::Migration[8.1]
  def up
    change_column :comment_votes, :id, :bigint
  end

  def down
    change_column :comment_votes, :id, :integer
  end
end
