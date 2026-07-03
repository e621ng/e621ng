# frozen_string_literal: true

require_relative "20260406172356_create_favorite_events"

class DropFavoriteEvents < ActiveRecord::Migration[8.1]
  def up
    CreateFavoriteEvents.new.down
  end

  def down
    CreateFavoriteEvents.new.up
  end
end
