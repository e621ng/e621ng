# frozen_string_literal: true

class AddBlipsUpdaterId < ActiveRecord::Migration[7.0]
  def change
    add_column :blips, :updater_id, :integer
    add_foreign_key :blips, :users, column: :updater_id
  end
end
