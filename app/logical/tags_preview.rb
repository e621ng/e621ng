class TagsPreview
  def initialize(tags: nil)
    @tags = Tag.scan_tags(tags).map {|x| {a: x, type: 'tag'}}
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
    implications.each do |imp|
      @tags += imp[1].map { |x| {a: imp[0], b: x, type: 'implication'} }
    end
  end

  def tag_types
    names = @tags.map { |tag| tag[:b] || tag[:a] }
    categories = Tag.categories_for(names)
    @tags.map! do |x|
      x[:tagType] = categories.fetch(x[:b] || x[:a], -1)
      x
    end
  end

  def serializable_hash(**options)
    @tags
  end
end
