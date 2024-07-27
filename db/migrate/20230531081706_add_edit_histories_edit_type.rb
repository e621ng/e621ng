# frozen_string_literal: true

class AddEditHistoriesEditType < ActiveRecord::Migration[7.0]
  def change
    add_column :edit_histories, :edit_type, :text, null: false, default: "original"
  end
end
