class RemoveInviterId < ActiveRecord::Migration[6.0]
  def change
    remove_column :users, :inviter_id
  end
end
