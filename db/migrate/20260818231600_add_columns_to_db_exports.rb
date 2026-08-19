# frozen_string_literal: true

class AddColumnsToDbExports < ActiveRecord::Migration[8.1]
  def change
    add_column(:db_exports, :columns, :jsonb, default: {}, null: false)
  end
end
