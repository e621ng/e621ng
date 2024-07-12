# frozen_string_literal: true

class MascotsAddAvailableOn < ActiveRecord::Migration[7.0]
  def change
    add_column :mascots, :available_on, :string, array: true, null: false, default: []
  end
end
