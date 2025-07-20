# frozen_string_literal: true

class StoreVideoMetadataAsJson < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :video_samples, :jsonb, default: {}, null: false
  end
end
