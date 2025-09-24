# frozen_string_literal: true

class AddExceptionLogIndexes < ActiveRecord::Migration[7.2]
  def change
    ExceptionLog.without_timeout do
      add_foreign_key :exception_logs, :users, column: :user_id
      add_index :exception_logs, :user_id
      add_index :exception_logs, :code
    end
  end
end
