# frozen_string_literal: true

class AddApplyToAutomodRules < ActiveRecord::Migration[8.1]
  def change
    add_column :automod_rules, :apply_to, :integer, null: false, default: 0
  end
end
