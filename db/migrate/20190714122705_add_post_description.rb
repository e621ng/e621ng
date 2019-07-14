class AddPostDescription < ActiveRecord::Migration[5.2]
  def change
    add_column :posts, :description, :text, null: false, default: ''
  end
end
