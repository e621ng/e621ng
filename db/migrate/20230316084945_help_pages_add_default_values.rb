# frozen_string_literal: true

class HelpPagesAddDefaultValues < ActiveRecord::Migration[7.0]
  def change
    change_column_null :help_pages, :related, false
    change_column_default :help_pages, :related, from: nil, to: ""
    change_column_null :help_pages, :title, false
    change_column_default :help_pages, :title, from: nil, to: ""
  end
end
