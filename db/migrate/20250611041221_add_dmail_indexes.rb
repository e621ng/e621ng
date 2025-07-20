# frozen_string_literal: true

class AddDmailIndexes < ActiveRecord::Migration[7.1]
  def change
    Dmail.without_timeout do
      add_index :dmails, %i[id owner_id to_id is_deleted], name: "index_dmails_for_inbox"
    end
  end
end
