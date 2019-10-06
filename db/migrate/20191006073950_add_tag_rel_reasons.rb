class AddTagRelReasons < ActiveRecord::Migration[6.0]
  def change
    add_column :tag_aliases, :reason, :text, null: false, default: ''
    add_column :tag_implications, :reason, :text, null: false, default: ''
  end
end
