# frozen_string_literal: true

class NewsUpdate < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.recent
    Cache.fetch("recent_news_v2", expires_in: 1.day) do
      order("id desc").first
    end
  end

  def invalidate_cache
    Cache.delete("recent_news_v2")
  end
end
