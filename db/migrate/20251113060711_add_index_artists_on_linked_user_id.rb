# frozen_string_literal: true

class AddIndexArtistsOnLinkedUserId < ActiveRecord::Migration[7.2]
  def change
    Artist.without_timeout do
      add_index :artists, :linked_user_id
    end
  end
end
