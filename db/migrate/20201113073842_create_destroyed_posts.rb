class CreateDestroyedPosts < ActiveRecord::Migration[6.0]
  def change
    create_table :destroyed_posts do |t|
      t.integer :post_id, null: false
      t.string :md5, null: false
      t.integer :destroyer_id, null: false
      t.inet :destroyer_ip_addr, null: false
      t.integer :uploader_id
      t.inet :uploader_ip_addr
      t.timestamp :upload_date
      t.json :post_data, null: false
      t.timestamps
    end
  end
end
