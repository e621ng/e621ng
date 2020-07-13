class AddBurIpAddr < ActiveRecord::Migration[6.0]
  def change
    add_column :bulk_update_requests, :user_ip_addr, :inet, null: false, default: '127.0.0.1'
  end
end
