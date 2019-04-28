class AddProfileInfo < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :profile_about, :text
    add_column :users, :profile_artinfo, :text
  end
end
