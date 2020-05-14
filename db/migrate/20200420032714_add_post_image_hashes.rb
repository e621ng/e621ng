class AddPostImageHashes < ActiveRecord::Migration[6.0]
  def change
    create_table :post_image_hashes do |t|
      t.references :post, null: false, foreign_key: true, index: false
      t.float :nw, null: false
      t.float :ne, null: false
      t.float :sw, null: false
      t.float :se, null: false
      t.binary :phash, null: true

      t.index :post_id, unique: true
    end
    add_index :post_image_hashes, [:nw, :ne, :sw, :se], name: :post_image_hashes_index
  end
end
