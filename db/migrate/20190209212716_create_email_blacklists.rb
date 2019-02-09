class CreateEmailBlacklists < ActiveRecord::Migration[5.2]
  def self.up
    create_table :email_blacklists do |t|
      t.timestamps null: false
      t.string :domain, null:false
      t.integer :creator_id, null: false
      t.string :reason, null: false
    end
  end

  def self.down
    drop_table :email_blacklists
  end
end
