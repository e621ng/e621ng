class CreatePostReportReason < ActiveRecord::Migration[5.2]
  def self.up
    create_table :post_report_reasons do |t|
      t.timestamps
      t.string :reason, null:false
      t.integer :creator_id, null:false
      t.column :creator_ip_addr, 'inet'
      t.string :description, null:false
    end
  end

  def self.down
    drop_table :post_report_reasons
  end
end
