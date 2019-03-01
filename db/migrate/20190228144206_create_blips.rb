class CreateBlips < ActiveRecord::Migration[5.2]
  def change
    create_table :blips do |t|
      t.column :creator_ip_addr, "inet", null: false
      t.column :creator_id, :integer, null: false
      t.column :body, :string, null: false
      t.column :response_to, :integer
      t.boolean :is_hidden, default: false
      t.column :body_index, "tsvector", :null => false
      t.timestamps
    end

    execute "CREATE INDEX index_blips_on_body_index ON blips USING GIN (body_index)"
    execute "CREATE TRIGGER trigger_blips_on_update BEFORE INSERT OR UPDATE ON blips FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('body_index', 'pg_catalog.english', 'body')"
  end
end
