# frozen_string_literal: true

class RemoveGeneratedVideos < ActiveRecord::Migration[7.1]
  def change
    remove_column :posts, :generated_samples
  end
end
