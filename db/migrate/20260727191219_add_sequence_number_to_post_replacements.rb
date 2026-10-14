# frozen_string_literal: true

class AddSequenceNumberToPostReplacements < ActiveRecord::Migration[8.1]
  def change
    add_column :post_replacements2, :sequence_number, :integer, null: true
  end
end
