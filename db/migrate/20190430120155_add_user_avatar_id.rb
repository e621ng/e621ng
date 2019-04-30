class AddUserAvatarId < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :avatar_id, :integer
  end
end
