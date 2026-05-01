class AddCustomTitleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :custom_title, :string, null: true, default: nil
  end
end
