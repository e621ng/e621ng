# frozen_string_literal: true

class AddFlareColorToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :flare_color, :integer
    add_index :users, :flare_color
  end
end
