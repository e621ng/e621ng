# frozen_string_literal: true

class DevProdCleanup < ActiveRecord::Migration[7.0]
  def up
    execute("DROP TYPE IF EXISTS post_status")
    execute("DROP INDEX IF EXISTS index_users_on_name_trgm")
    drop_table :janitor_trials
  end
end
