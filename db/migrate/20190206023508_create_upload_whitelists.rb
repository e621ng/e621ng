class CreateUploadWhitelists < ActiveRecord::Migration[5.2]
  def self.up
    create_table :upload_whitelists do |t|
      t.column :pattern, :string, null: false
      t.column :note, :string
      t.column :reason, :string
      t.column :allowed, :boolean, null: false, default: true
      t.column :hidden, :boolean, null: false, default: false
      t.timestamps null: false
    end
  end

  def self.down
    drop_table :upload_whitelists
  end
end
