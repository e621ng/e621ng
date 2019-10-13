class AddNotesChangedToArtistVersion < ActiveRecord::Migration[6.0]
  def change
    add_column :artist_versions, :notes_changed, :boolean, default: false
  end
end
