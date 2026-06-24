# frozen_string_literal: true

class AddChecksumToDbExports < ActiveRecord::Migration[8.1]
  def change
    add_column :db_exports, :checksum, :string
  end
end
