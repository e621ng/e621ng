class BulkRelatedTagQuery
  include ActiveModel::Serializers::JSON
  include ActiveModel::Serializers::Xml

  attr_reader :query, :category, :user

  def initialize(query: nil, category: nil, user: nil)
    @user = user
    @query = Tag.normalize_query(query).split(' ').slice(0, 25)
    @category = category
  end

  def tags
    if category.present?
      related_tags_by_category
    elsif query.present?
      related_tags
    else
      {}
    end
  end

  def serializable_hash(**options)
    tags
  end

  protected

  def related_tags
    @related_tags ||= Tag.where(name: @query).each_with_object({}) do |tag, hash|
      related = tag.related_tag_array
      categories = Tag.categories_for(related.map(&:first))

      hash[tag.name] = related.map {|name, count| [name, count.to_i, categories.fetch(name, -1)]}
    end
  end

  def related_tags_by_category
    @related_tags_by_category ||= begin
      cat = Tag.categories.value_for(category)

      @query.each_with_object({}) do |tag, hash|
        related = RelatedTagCalculator.calculate_from_sample_to_array(tag, cat)
        categories = Tag.categories_for(related.map(&:first))

        hash[tag] = related.map {|name, count| [name, count.to_i, categories.fetch(name, -1)]}
      end
    end
  end
end
