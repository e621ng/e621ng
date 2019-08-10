class AllowNullBanExpiresAt < ActiveRecord::Migration[5.2]
  def change
    change_column_null :bans, :expires_at, true
  end
end
