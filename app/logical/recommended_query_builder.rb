# frozen_string_literal: true

class RecommendedQueryBuilder < ElasticPostQueryBuilder
  CHARACTER_WEIGHT = 2.0
  COPYRIGHT_WEIGHT = 1.5
  SPECIES_WEIGHT = 1.25

  def initialize(post, **kwargs)
    @post = post
    exclusion_query = "-id:#{post.id} -parent:#{post.id} -child:#{post.id} order:random randseed:#{post.id}"
    super(exclusion_query, always_show_deleted: false, **kwargs)
  end

  def build
    super

    # Add artist tags as OR constraints (minimum_should_match: 1 applied by create_query_obj)
    artist_names = @post.known_artist_tags.sort_by(&:name).first(10).map(&:name)
    should.concat(artist_names.map { |t| { term: { tags: t } } })

    # Build weighted function_score: base randomness + boosts for shared character/copyright tags
    character_tags = @post.tags_for_category("character").min_by(10, &:post_count).map(&:name)
    copyright_tags = @post.tags_for_category("copyright").min_by(10, &:post_count).map(&:name)
    species_tags = @post.tags_for_category("species").min_by(10, &:post_count).map(&:name)

    functions = [{ random_score: { seed: @post.id, field: "id" } }]
    functions << { filter: { terms: { tags: character_tags } }, weight: CHARACTER_WEIGHT } if character_tags.any?
    functions << { filter: { terms: { tags: copyright_tags } }, weight: COPYRIGHT_WEIGHT } if copyright_tags.any?
    functions << { filter: { terms: { tags: species_tags } }, weight: SPECIES_WEIGHT } if species_tags.any?

    @function_score = {
      functions: functions,
      score_mode: :sum,
      boost_mode: :replace,
    }
  end
end
