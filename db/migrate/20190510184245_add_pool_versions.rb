class AddPoolVersions < ActiveRecord::Migration[5.2]
  def change
      create_table "pool_versions", :force => true do |t|
        t.integer  "pool_id", :null => false
        t.integer  "post_ids", :array => true, :default => [], :null => false
        t.integer  "added_post_ids", :array => true, :default => [], :null => false
        t.integer  "removed_post_ids", :array => true, :default => [], :null => false
        t.integer  "updater_id"
        t.inet     "updater_ip_addr", :limit => nil
        t.text     "description"
        t.boolean  "description_changed", :default => false, :null => false
        t.text     "name"
        t.boolean  "name_changed", :default => false, :null => false
        t.datetime "created_at"
        t.datetime "updated_at"
        t.boolean  "is_active", :default => true, :null => false
        t.boolean  "is_deleted", :default => false, :null => false
        t.string   "category"
        t.integer  "version", :default => 1, :null => false
      end

      add_index "pool_versions", :pool_id
      add_index "pool_versions", :updater_id
      add_index "pool_versions", :updater_ip_addr
  end
end
