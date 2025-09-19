# frozen_string_literal: true

class TagsPreview
  def initialize(tags: nil)
    @raw_names = TagQuery.scan(tags).map(&:downcase).compact_blank.uniq
    resolve_categories
    resolve_aliases
    resolve_implications
    load_tags
  end

  # Tags with a prefix should be either found in the DB or assigned that category in the output.
  def resolve_categories
    @resolved_names = {}
    @name_categories = {}

    @tag_names = @raw_names.map do |name|
      if name =~ /\A(#{Tag.categories.regexp}):(.+)\Z/
        resolved = Tag.normalize_name($2).downcase
        category = Tag.categories.value_for($1)
        @resolved_names[name] = resolved
        @name_categories[resolved] = category
        resolved
      else
        @resolved_names[name] = name
        name
      end
    end.uniq
  end

  def resolve_aliases
    @aliases = TagAlias.to_aliased_with_originals(@tag_names)
    @aliased_names = @aliases.values.uniq
  end

  def resolve_implications
    @implications = TagImplication
                    .descendants_with_originals(@aliased_names)
                    .transform_values(&:to_a)

    implied_tags = @implications.values.flatten.uniq
    if implied_tags.any?
      sub_implications = TagImplication
                         .descendants_with_originals(implied_tags)
                         .transform_values(&:to_a)
      @implications.merge!(sub_implications)
    end
  end

  def load_tags
    all_names = (@tag_names + @aliases.values + @implications.values.flatten).uniq
    @tags = Tag.where(name: all_names).index_by(&:name)
  end

  def serializable_hash(*)
    seen = Set.new

    (@raw_names + @aliases.values + @implications.values.flatten).uniq.filter_map do |raw_name|
      resolved = @resolved_names[raw_name] || raw_name

      next if seen.include?(resolved)
      seen << resolved

      canonical = @aliases[resolved] || resolved
      tag = @tags[canonical]

      {
        id: tag&.id,
        name: raw_name,
        resolved: (resolved if resolved != raw_name),
        category: tag&.category || @name_categories[resolved],
        post_count: tag&.post_count,
        alias: (canonical if canonical != resolved),
        implies: (@implications[canonical].map(&:to_s) if @implications.key?(canonical)),
      }.compact
    end
  end
end
