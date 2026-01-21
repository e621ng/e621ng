# frozen_string_literal: true

class RelatedTagQuery
  attr_reader :query, :category_id

  def initialize(query: nil, category_id: nil)
    @query = TagAlias.to_aliased(query.to_s.downcase.strip).join(" ")
    @category_id = category_id
  end

  def as_json(_options = {})
    serializable_hash
  end

  def tags
    if query =~ /\*/
      pattern_matching_tags
    elsif category_id.present?
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
    tags_with_categories(tags).map { |tag, category_id| { name: tag, category_id: category_id } }
  end

  protected

  def tags_with_categories(list_of_tag_names)
    Tag.categories_for(list_of_tag_names)
  end

  def pattern_matching_tags
    Tag.name_matches(query).where("post_count > 0").order("post_count desc").limit(50).sort_by(&:name).map(&:name)
  end

  def related_tags
    tag = Tag.find_by_normalized_name(query)

    if tag
      tag.related_tag_array.map(&:first)
    else
      []
    end
  end

  def related_tags_by_category
    RelatedTagCalculator.calculate_from_sample_to_array(query, category_id).map(&:first)
  end

  def wiki_page
    WikiPage.titled(query)
  end
end
