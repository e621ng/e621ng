class DropUnusedTables < ActiveRecord::Migration[6.0]
  def change
    drop_table :advertisement_hits
    drop_table :advertisements
    drop_table :amazon_backups
    drop_table :anti_voters
    drop_table :delayed_jobs
    drop_table :super_voters
    drop_table :tag_subscriptions
    drop_table :token_buckets
  end
end
