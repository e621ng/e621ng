# frozen_string_literal: true

class AddFlairColorToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :flair_color, :integer
    add_index :users, :flair_color
  end
end
