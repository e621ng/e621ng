# frozen_string_literal: true

class RemoveUnusedTextIndexColumns < ActiveRecord::Migration[7.0]
  def up
    drop_trigger_and_column(:blips, :body)
    drop_trigger_and_column(:comments, :body)
    drop_trigger_and_column(:dmails, :message)
    drop_trigger_and_column(:forum_posts, :text)
    drop_trigger_and_column(:forum_topics, :text)
    drop_trigger_and_column(:notes, :body)
    drop_trigger_and_column(:wiki_pages, :body)
  end

  def drop_trigger_and_column(table, column)
    execute "DROP TRIGGER trigger_#{table}_on_update ON #{table}"
    remove_column table, "#{column}_index"
  end
end
