class AddExceptionLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :exception_logs do |t|
      t.timestamps
      t.string :class_name, null: false
      t.column :ip_addr, :inet, null: false
      t.string :version, null: false
      t.text :extra_params, null: true
      t.text :message, null: false
      t.text :trace, null: false
      t.column :code, :uuid, null: false
      t.integer :user_id, null: true
    end
  end
end
