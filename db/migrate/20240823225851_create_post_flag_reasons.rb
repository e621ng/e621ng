# frozen_string_literal: true

class CreatePostFlagReasons < ActiveRecord::Migration[7.1]
  def change
    create_table(:post_flag_reasons) do |t|
      t.references(:creator, null: false, foreign_key: { to_table: :users })
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, null: false, foreign_key: { to_table: :users })
      t.inet(:updater_ip_addr, null: false)
      t.string(:name, null: false, index: { unique: true })
      t.string(:reason, null: false)
      t.string(:text, null: false)
      t.boolean(:parent, null: false, default: false)
      t.integer(:order, null: false)
      t.timestamps
    end
  end
end
