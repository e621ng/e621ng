# frozen_string_literal: true

class AddIsSubscriptionToSavedSearches < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_searches, :is_subscription, :boolean, null: false, default: false
    # At most one subscription anchor per user; also makes find-or-create race-safe
    add_index :saved_searches, :user_id, unique: true, where: "is_subscription", name: "index_saved_searches_on_user_id_subscription"
  end
end
