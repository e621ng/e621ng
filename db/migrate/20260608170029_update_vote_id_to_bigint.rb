# frozen_string_literal: true

class UpdateVoteIdToBigint < ActiveRecord::Migration[8.1]
  def up
    PostVotes.without_timeout do
      change_column :post_votes, :id, :bigint
      change_column :comment_votes, :id, :bigint
      execute "ALTER SEQUENCE post_votes_id_seq AS bigint"
      execute "ALTER SEQUENCE comment_votes_id_seq AS bigint"
    end
  end

  def down
    PostVotes.without_timeout do
      execute "ALTER SEQUENCE post_votes_id_seq AS integer"
      execute "ALTER SEQUENCE comment_votes_id_seq AS integer"
      change_column :post_votes, :id, :integer
      change_column :comment_votes, :id, :integer
    end
  end
end
