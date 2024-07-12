# frozen_string_literal: true

class TagsPreview
  def initialize(tags: nil)
    @tags = TagQuery.scan(tags).map {|x| {a: x, type: 'tag'}}
    aliases
    implications
    tag_types
  end

  def aliases
    names = @tags.map{ |tag| tag[:a] }.reject {|y| y.blank?}
    aliased = TagAlias.to_aliased_with_originals(names).reject {|k,v| k == v }
    @tags.map! do |tag|
      if aliased[tag[:a]]
        {a: tag[:a], b: aliased[tag[:a]], type: 'alias'}
      else
        tag
      end
    end
  end

  def implications
    names = @tags.map {|tag| tag[:b] || tag[:a] }
    implications = TagImplication.descendants_with_originals(names)
    implications.each do |implication, descendants|
      @tags += descendants.map { |descendant| {a: implication, b: descendant, type: 'implication'} }
    end
  end

  def tag_types
    names = @tags.map { |tag| [tag[:a], tag[:b]] }.flatten.compact.uniq
    categories = Tag.categories_for(names)
    @tags.map! do |tag|
      tag[:tagTypeA] = categories.fetch(tag[:a], -1)
      tag[:tagTypeB] = categories.fetch(tag[:b], -1) if tag[:b]
      tag
    end
  end

  def serializable_hash(*)
    @tags
  end
end
