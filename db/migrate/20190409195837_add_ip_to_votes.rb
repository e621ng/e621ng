class AddIpToVotes < ActiveRecord::Migration[5.2]
  def change
    add_column :comment_votes, :user_ip_addr, 'inet', null: true
    add_column :post_votes, :user_ip_addr, 'inet', null: true
  end
end
