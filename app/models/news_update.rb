class NewsUpdate < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.recent
    Cache.get("recent_news_v2", 1.day) do
      order("id desc").first
    end
  end

  def invalidate_cache
    Cache.delete("recent_news_v2")
  end
end
