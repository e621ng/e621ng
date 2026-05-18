# frozen_string_literal: true

class AddExceptionLogIndexOnCreatedAt < ActiveRecord::Migration[7.2]
  def change
    add_index :exception_logs, :created_at # Needed for pruning old logs
  end
end
