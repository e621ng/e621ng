# frozen_string_literal: true

class UpgradeApiKeys < ActiveRecord::Migration[7.1]
  def change
    ApiKey.without_timeout do
      add_column :api_keys, :name, :string
      add_column :api_keys, :last_used_at, :datetime
      add_column :api_keys, :last_ip_address, :inet
      add_column :api_keys, :last_user_agent, :text
      add_column :api_keys, :expires_at, :datetime

      ApiKey.where(name: nil).find_each do |api_key|
        api_key.update_columns(
          name: "Legacy API Key ##{api_key.id}",
          expires_at: 6.months.from_now,
        )
      end
      change_column_null :api_keys, :name, false

      remove_index :api_keys, :user_id
      add_index :api_keys, %i[name user_id], unique: true
    end
  end
end
