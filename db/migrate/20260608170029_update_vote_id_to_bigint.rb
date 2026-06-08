# frozen_string_literal: true

class UpdateVoteIdToBigint < ActiveRecord::Migration[8.1]
  def up
    change_column :post_votes, :id, :bigint
    change_column :comment_votes, :id, :bigint
  end

  def down
    change_column :post_votes, :id, :integer
    change_column :comment_votes, :id, :integer
  end
end
