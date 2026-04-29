# frozen_string_literal: true

class FavoriteEventPartitionJob < ApplicationJob
  queue_as :low_prio

  def perform
    FavoriteEvent.ensure_upcoming_partitions!
    FavoriteEvent.drop_old_partitions!
  end
end
