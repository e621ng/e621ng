# frozen_string_literal: true

class ChangeReasonLengthInPostReplacements2 < ActiveRecord::Migration[7.1]
  def up
    change_column :post_replacements2, :reason, :string, limit: 300
  end

  def down
    change_column :post_replacements2, :reason, :string, limit: nil
  end
end
