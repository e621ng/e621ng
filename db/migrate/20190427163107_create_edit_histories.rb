class CreateEditHistories < ActiveRecord::Migration[5.2]
  def self.up
    create_table :edit_histories do |t|
      t.timestamps
      t.text :body, null: false
      t.text :subject, null: true
      t.string :versionable_type, limit: 100, null: false
      t.integer :versionable_id, null: false
      t.integer :version, null: false
      t.column :ip_addr, "inet", null: false
      t.integer :user_id, index: true, null: false
      t.index [:versionable_id, :versionable_type]
    end
  end

  def self.down
    drop_table :edit_histories
  end
end
