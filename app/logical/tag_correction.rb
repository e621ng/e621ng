# frozen_string_literal: true

class TagCorrection
  include ActiveModel::Model

  attr_reader :tag

  delegate :category, :post_count, :post_count_from_opensearch, :post_count_from_db, to: :tag

  def initialize(tag_id)
    @tag = Tag.find(tag_id)
  end

  def as_json(_options = {})
    attributes
  end

  def attributes
    {
      post_count: post_count,
      post_count_from_opensearch: post_count_from_opensearch,
      post_count_from_db: post_count_from_db,
      category: category,
      category_cache: category_cache,
      tag: tag,
    }
  end

  def category_cache
    Cache.fetch("tc:#{tag.name}")
  end

  def fix!
    TagPostCountJob.perform_later(tag.id)
    tag.update_category_cache
  end
end
