# frozen_string_literal: true

class TagCorrection
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  attr_reader :tag
  delegate :category, :post_count, :real_post_count, to: :tag

  def initialize(tag_id)
    @tag = Tag.find(tag_id)
  end

  def attributes
    { post_count: post_count, real_post_count: real_post_count, category: category, category_cache: category_cache, tag: tag }
  end

  def category_cache
    Cache.fetch("tc:#{tag.name}")
  end

  def fix!
    TagPostCountJob.perform_later(tag.id)
    tag.update_category_cache
  end
end
