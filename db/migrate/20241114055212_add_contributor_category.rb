# frozen_string_literal: true

class AddContributorCategory < ActiveRecord::Migration[7.1]
  def change
    Post.without_timeout do
      add_column(:posts, :tag_count_contributor, :integer, default: 0, null: false)
    end
  end
end
