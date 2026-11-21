# frozen_string_literal: true

class AddLandingFieldsToForumCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :forum_categories, :color, :string
    add_column :forum_categories, :landing_topic_count, :integer, null: false, default: 5
  end
end
