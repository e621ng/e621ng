class RelatedTagQuery
  include ActiveModel::Serializers::JSON
  include ActiveModel::Serializers::Xml

  attr_reader :query, :category, :user

  def initialize(query: nil, category: nil, user: nil)
    @user = user
    @query = TagAlias.to_aliased(query.to_s.downcase.strip).join(" ")
    @category = category
  end

  def tags
    if query =~ /\*/
      pattern_matching_tags
    elsif category.present?
      related_tags_by_category
    elsif query.present?
      related_tags
    else
      []
    end
  end

  def tags_for_html
    tags_with_categories(tags)
  end

  def serializable_hash(*)
    {
      query: query,
      category: category,
      tags: tags_with_categories(tags)
    }
  end

protected

  def tags_with_categories(list_of_tag_names)
    Tag.categories_for(list_of_tag_names).to_a
  end

  def pattern_matching_tags
    Tag.name_matches(query).where("post_count > 0").order("post_count desc").limit(50).sort_by {|x| x.name}.map(&:name)
  end

  def related_tags
    tag = Tag.find_by_name(query.strip)

    if tag
      tag.related_tag_array.map(&:first)
    else
      []
    end
  end

  def related_tags_by_category
    RelatedTagCalculator.calculate_from_sample_to_array(query, Tag.categories.value_for(category)).map(&:first)
  end

  def wiki_page
    WikiPage.titled(query).first
  end
end
