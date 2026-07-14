# frozen_string_literal: true

class AddVoteScoreToForumPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :forum_posts, :vote_score, :decimal
  end
end
