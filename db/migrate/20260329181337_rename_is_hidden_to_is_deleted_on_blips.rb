# frozen_string_literal: true

class RenameIsHiddenToIsDeletedOnBlips < ActiveRecord::Migration[8.0]
  def change
    rename_column :blips, :is_hidden, :is_deleted
  end
end
