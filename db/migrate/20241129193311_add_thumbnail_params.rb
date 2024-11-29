# frozen_string_literal: true

class AddThumbnailParams < ActiveRecord::Migration[7.1]
  def change
    add_column :uploads, :thumbnail, :string
    add_column :posts, :thumbnail, :string
  end
end
