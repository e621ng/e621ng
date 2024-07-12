# frozen_string_literal: true

class RemovePoolIsDeleted < ActiveRecord::Migration[6.1]
  def up
    remove_column :pools, :is_deleted
    remove_column :pool_versions, :is_deleted
  end
end
