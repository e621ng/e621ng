class AddPostBackgroundColor < ActiveRecord::Migration[6.0]
  def change
    add_column :posts, :bg_color, :string, null: true
  end
end
