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
    @tags = Tag.where(name: @query)
    @tags = @tags.inject({}) do |all, x|
      related = x.related_tag_array
      categories = Tag.categories_for(related.map(&:first))
      all[x.name] = related.map { |x| [x[0], x[1].to_i, categories.fetch(x[0], -1)] }
      all
    end
    @tags
  end

  def related_tags_by_category
    cat = Tag.categories.value_for(category)
    @tags = @query.inject({}) do |all, tag|
      related = RelatedTagCalculator.calculate_from_sample_to_array(tag, cat)
      categories = Tag.categories_for(related.map(&:first))
      Rails.logger.warn("[cats] #{related.inspect}")
      all[tag] = related.map { |y| [y[0], y[1].to_i, categories.fetch(y[0], -1)] }
      all
    end
    @tags
  end
end
