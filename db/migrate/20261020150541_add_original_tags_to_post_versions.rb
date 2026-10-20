# frozen_string_literal: true

class AddOriginalTagsToPostVersions < ActiveRecord::Migration[8.1]
  def change
    add_column(:post_versions, :original_tags, :text, array: true, null: false, default: [])
  end
end
