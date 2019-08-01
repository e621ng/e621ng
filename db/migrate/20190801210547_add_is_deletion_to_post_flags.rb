class AddIsDeletionToPostFlags < ActiveRecord::Migration[5.2]
  def change
    add_column :post_flags, :is_deletion, :bool, null: false, default: false
  end
end
