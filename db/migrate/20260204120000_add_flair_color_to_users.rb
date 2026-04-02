# frozen_string_literal: true

class AddFlairColorToUsers < ActiveRecord::Migration[7.0]
  def up
    unless column_exists?(:users, :flair_color)
      add_column :users, :flair_color, :integer
    end

    unless index_exists?(:users, :flair_color)
      add_index :users, :flair_color
    end
  end

  def down
    if index_exists?(:users, :flair_color)
      remove_index :users, :flair_color
    end

    if column_exists?(:users, :flair_color)
      remove_column :users, :flair_color
    end
  end
end
