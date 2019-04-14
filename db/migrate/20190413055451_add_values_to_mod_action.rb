class AddValuesToModAction < ActiveRecord::Migration[5.2]
  def change
    ModAction.without_timeout do
      add_column :mod_actions, :values, :json
      add_column :mod_actions, :action, :string, null: false, default: 'unknown_action'
      remove_column :mod_actions, :description, :text
    end
  end
end
