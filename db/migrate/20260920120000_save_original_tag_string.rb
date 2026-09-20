# frozen_string_literal: true

class SaveOriginalTagString < ActiveRecord::Migration[8.1]
  def change
    add_column(:post_versions, :original_tags, :text, null: false, default: "")
  end
end
