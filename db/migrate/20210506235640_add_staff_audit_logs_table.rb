class AddStaffAuditLogsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :staff_audit_logs do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true, index: true
      t.string :action, null: false, default: 'unknown_action'
      t.json :values
    end
  end
end
