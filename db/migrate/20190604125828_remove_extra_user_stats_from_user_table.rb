class RemoveExtraUserStatsFromUserTable < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :post_upload_count
    remove_column :users, :post_update_count
    remove_column :users, :note_update_count
    remove_column :users, :favorite_count
    remove_column :users, :set_count
  end
end
