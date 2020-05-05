class ChangeTagSubscriptionTagQueryDelimiter < ActiveRecord::Migration[4.2]
  def change
    execute "set statement_timeout = 0"
  end
end
