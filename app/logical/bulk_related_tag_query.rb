# frozen_string_literal: true

class BulkRelatedTagQuery
  include ActiveModel::Serializers::JSON

  attr_reader :query, :category_id

  def initialize(query: nil, category_id: nil)
    @query = TagQuery.normalize(query).split.slice(0, 25)
    @category_id = category_id
  end

  def tags
    if category_id.present?
      related_tags_by_category
    elsif query.present?
      related_tags
    else
      {}
    end
  end

  def serializable_hash(*)
    tags
  end

  protected

  def related_tags
    @related_tags ||= Tag.where(name: @query).each_with_object({}) do |tag, hash|
      related = tag.related_tag_array
      categories = Tag.categories_for(related.map(&:first))

      hash[tag.name] = related.map do |name, count|
        {
          name: name,
          count: count.to_i,
          category_id: categories.fetch(name, -1),
        }
      end
    end
  end

  def related_tags_by_category
    @related_tags_by_category ||= @query.each_with_object({}) do |tag_name, hash|
      related = RelatedTagCalculator.calculate_from_sample_to_array(tag_name, category_id)
      categories = Tag.categories_for(related.map(&:first))

      hash[tag_name] = related.map do |name, count|
        {
          name: name,
          count: count.to_i,
          category_id: categories.fetch(name, -1),
        }
      end
    end
  end
end
