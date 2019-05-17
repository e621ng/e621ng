class AddPostVersions < ActiveRecord::Migration[5.2]
  def change
    create_table "post_versions", :force => true do |t|
      t.integer  "post_id", :null => false
      t.text     "tags", :null => false
      t.text     "added_tags", :null => false, :array => true, :default => []
      t.text     "removed_tags", :null => false, :array => true, :default => []
      t.text     "locked_tags", null: true
      t.text     "added_locked_tags", null: false, array: true, default: []
      t.text     "removed_locked_tags", null: false, array: true, default: []
      t.integer  "updater_id"
      t.inet     "updater_ip_addr", :limit => nil, :null => true
      t.datetime "updated_at", :null => false
      t.string   "rating", :limit => 1
      t.boolean  "rating_changed", :null => false, :default => false
      t.integer  "parent_id"
      t.boolean  "parent_changed", :null => false, :default => false
      t.text     "source"
      t.boolean  "source_changed", :null => false, :default => false
      t.text     "description", null: true
      t.boolean  "description_changed", null: false, default: false
      t.integer  "version", :null => false, :default => 1
    end

    add_index "post_versions", :post_id
    add_index "post_versions", :updated_at
    add_index "post_versions", :updater_id
    add_index "post_versions", :updater_ip_addr
  end
end
