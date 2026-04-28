# frozen_string_literal: true

class RenameIsHiddenToIsDeletedOnBlips < ActiveRecord::Migration[8.0]
  def up
    Blip.without_timeout do
      rename_column :blips, :is_hidden, :is_deleted
    end

    ModAction.without_timeout do
      execute("UPDATE mod_actions SET action = 'blip_destroy' WHERE action = 'blip_delete'")
      execute("UPDATE mod_actions SET action = 'blip_delete' WHERE action = 'blip_hide'")
      execute("UPDATE mod_actions SET action = 'blip_undelete' WHERE action = 'blip_unhide'")
    end
  end

  def down
    Blip.without_timeout do
      rename_column :blips, :is_deleted, :is_hidden
    end

    ModAction.without_timeout do
      execute("UPDATE mod_actions SET action = 'blip_hide' WHERE action = 'blip_delete'")
      execute("UPDATE mod_actions SET action = 'blip_unhide' WHERE action = 'blip_undelete'")
      execute("UPDATE mod_actions SET action = 'blip_delete' WHERE action = 'blip_destroy'")
    end
  end
end
