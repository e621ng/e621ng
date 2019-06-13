class FixPasswordResets < ActiveRecord::Migration[5.2]
  def change
    remove_column :user_password_reset_nonces, :email
    add_column :user_password_reset_nonces, :user_id, :integer, null: false
  end
end
