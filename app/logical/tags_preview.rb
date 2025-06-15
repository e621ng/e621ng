# frozen_string_literal: true

class TagsPreview
  def initialize(tags: nil)
    @tag_names = TagQuery.scan(tags).map(&:downcase).compact_blank.uniq
    resolve_categories
    resolve_aliases
    resolve_implications
    load_tags
  end

  # Tags with a prefix should be either found in the DB or assigned that category in the output.
  def resolve_categories
    @name_categories = {}
    @name_from = {}

    @tag_names = @tag_names.flat_map do |tag|
      if tag =~ /\A(#{Tag.categories.regexp}):(.+)\Z/
        stripped = Tag.normalize_name($2).downcase
        @name_categories[stripped] = Tag.categories.value_for($1)
        @name_from[stripped] = tag
        stripped
      else
        tag
      end
    end.uniq
  end

  def resolve_aliases
    @aliases = TagAlias.to_aliased_with_originals(@tag_names)
    @aliased_names = @aliases.values.uniq
  end

  def resolve_implications
    @implications = TagImplication.descendants_with_originals(@aliased_names)
  end

  def load_tags
    all_names = (@tag_names + @aliases.values + @implications.values.flatten).uniq
    @tags = Tag.where(name: all_names).index_by(&:name)
  end

  def serializable_hash(*)
    seen = Set.new

    (@tag_names + @aliases.values + @implications.values.flatten).uniq.filter_map do |name|
      next if seen.include?(name)
      seen << name

      tag = @tags[name]

      {
        id: tag&.id,
        name: name,
        category: tag&.category || @name_categories[name],
        post_count: tag&.post_count,
        alias: (@aliases[name] if @aliases.key?(name) && @aliases[name] != name),
        implies: (@implications[name].map(&:to_s) if @implications.key?(name)),
        from: @name_from[name]
      }.compact
    end
  end
end
