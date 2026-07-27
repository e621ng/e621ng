# frozen_string_literal: true

class CreateAsnRanges < ActiveRecord::Migration[8.1]
  def change
    # No timestamps: rows are bulk-replaced wholesale on every dataset refresh.
    create_table :asn_ranges do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.inet :first_ip, null: false
      t.inet :last_ip, null: false
      t.bigint :asn, null: false
      t.string :name, null: false
      t.string :country, null: false, default: ""
    end
    add_index :asn_ranges, :first_ip, unique: true
  end
end
