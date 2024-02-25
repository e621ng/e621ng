# frozen_string_literal: true

class RemoveArtistCommentaries < ActiveRecord::Migration[6.1]
  def change
    remove_column :uploads, :artist_commentary_title
    remove_column :uploads, :artist_commentary_desc
    remove_column :uploads, :include_artist_commentary

    drop_table :artist_commentaries
    drop_table :artist_commentary_versions
  end
end
