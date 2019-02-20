class RemovePostDisapprovals < ActiveRecord::Migration[5.2]
  def change
    drop_table :post_disapprovals
  end
end
