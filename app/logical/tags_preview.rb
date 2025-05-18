# frozen_string_literal: true

class TagsPreview
  def initialize(tags: nil)
    @tag_names = TagQuery.scan(tags).map(&:downcase).compact_blank.uniq
    resolve_aliases
    resolve_implications
    load_tags
  end

  def resolve_aliases
    @aliases = TagAlias.to_aliased_with_originals(@tag_names)
    @aliased_names = @aliases.values.uniq
  end

  def resolve_implications
    @reverse_implications = Hash.new { |h, k| h[k] = [] }
    @implications = TagImplication.descendants_with_originals(@aliased_names).transform_values(&:to_a).tap do |imp|
      imp.each { |a, d| d.each { |b| @reverse_implications[b] << a } }
    end
  end

  def load_tags
    all_names = (@aliased_names + @implications.values.flatten).uniq
    @tags = Tag.where(name: all_names).index_by(&:name)
  end

  def serializable_hash(*)
    all_tag_names = (@aliased_names + @implications.values.flatten).uniq

    all_tag_names.map do |name|
      tag = @tags[name]

      {
        id: tag&.id,
        name: name,
        alias: (@aliases.key(name) if @aliases.key(name) != name),
        category: tag&.category,
        post_count: tag&.post_count || 0,
        implied: @aliased_names.exclude?(name),
        implied_by: Array(@reverse_implications[name]).map(&:to_s),
        implies: Array(@implications[name]).map(&:to_s),
      }.compact
    end
  end
end
