class AddArtistLockStatus < ActiveRecord::Migration[6.0]
  def change
    add_column :artists, :is_locked, :boolean, nil: false, default: false
  end
end
