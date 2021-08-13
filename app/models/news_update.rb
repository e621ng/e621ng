class NewsUpdate < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.recent
    Cache.get('most_recent_news_entry', 1.day) do
      order('id desc').first
    end
  end

  def invalidate_cache
    Cache.delete('most_recent_news_entry')
  end
end
