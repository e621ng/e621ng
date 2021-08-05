class NewsUpdate < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.recent
    @recent_news ||= Cache.get('recent_news', 1.day) do
      self.order('id desc').first(1)
    end
  end

  def invalidate_cache
    Cache.delete('recent_news')
  end
end
