# frozen_string_literal: true

class AddArtistNamesToPools < ActiveRecord::Migration[7.1]
  def change
    add_column(:pools, :artist_names, :string, null: false, array: true, default: [])
  end
end
