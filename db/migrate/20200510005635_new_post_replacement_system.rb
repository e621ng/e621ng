class NewPostReplacementSystem < ActiveRecord::Migration[6.0]
  def change
    remove_column :post_replacements, :original_url, :text
    remove_column :post_replacements, :replacement_url, :text
    remove_column :post_replacements, :file_ext_was, :string
    remove_column :post_replacements, :file_size_was, :integer
    remove_column :post_replacements, :md5_was, :string
    remove_column :post_replacements, :image_width_was, :integer
    remove_column :post_replacements, :image_height_was, :integer
    add_column :post_replacements, :creator_ip_addr, :inet, null: false
    add_column :post_replacements, :source, :string
    add_column :post_replacements, :file_name, :string
    add_column :post_replacements, :storage_id, :string, null: false
    add_column :post_replacements, :status, :string, null: false, default: 'pending'
    add_column :post_replacements, :reason, :string, null: false
    add_column :post_replacements, :protected, :boolean, default: false
  end
end
