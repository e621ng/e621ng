# frozen_string_literal: true

class RecommendedQueryBuilder < ElasticPostQueryBuilder
  def initialize(post, mode: :artist, **kwargs)
    @post = post
    @mode = mode
    exclusion_query = "-id:#{post.id} -parent:#{post.id} -child:#{post.id} order:random randseed:#{post.id}"
    super(exclusion_query, always_show_deleted: false, **kwargs)
  end

  def build
    super

    if @mode == :tags
      build_for_tags
    else
      build_for_artist
    end
  end

  private

  WEIGHTS_FOR_ARTIST = {
    character: 2.0,
    copyright: 1.5,
    species: 1.25,
  }.freeze

  def build_for_artist
    # Add artist tags as OR constraints (minimum_should_match: 1 applied by create_query_obj)
    artist_names = @post.known_artist_tags.sort_by(&:name).first(10).map(&:name)
    should.concat(artist_names.map { |t| { term: { tags: t } } })

    pool_ids = @post.pool_ids
    must_not.push({ terms: { pools: pool_ids } }) if pool_ids.any?

    # Build weighted function_score: base randomness + boosts for shared character/copyright tags
    character_tags = @post.tags_for_category("character").min_by(10, &:post_count).map(&:name)
    copyright_tags = @post.tags_for_category(tm("{{copyright}}")).min_by(10, &:post_count).map(&:name)
    species_tags = @post.tags_for_category("species").min_by(10, &:post_count).map(&:name)

    functions = [{ random_score: { seed: @post.id, field: "id" } }]
    functions << { filter: { terms: { tags: character_tags } }, weight: WEIGHTS_FOR_ARTIST[:character] } if character_tags.any?
    functions << { filter: { terms: { tags: copyright_tags } }, weight: WEIGHTS_FOR_ARTIST[:copyright] } if copyright_tags.any?
    functions << { filter: { terms: { tags: species_tags } }, weight: WEIGHTS_FOR_ARTIST[:species] } if species_tags.any?

    @function_score = {
      functions: functions,
      score_mode: :sum,
      boost_mode: :replace,
    }
  end

  MAX_TAGS = 10
  WEIGHTS_FOR_TAGS = {
    character: 2.0,
    species: 1.0,
  }.freeze

  def build_for_tags
    pool_ids = @post.pool_ids
    must_not.push({ terms: { pools: pool_ids } }) if pool_ids.any?

    # Posts by the same artists are served by the :artist mode
    artist_names = @post.known_artist_tags.map(&:name)
    must_not.push({ terms: { tags: artist_names } }) if artist_names.any?

    # Least common character/species tags; score = weighted count of shared tags
    selected_tags = (@post.tags_for_category("character") + @post.tags_for_category("species"))
                    .min_by(MAX_TAGS, &:post_count)
    should.concat(selected_tags.map do |tag|
      {
        constant_score: {
          filter: { term: { tags: tag.name } },
          boost: WEIGHTS_FOR_TAGS.fetch(tag.category_name.to_sym),
        },
      }
    end)

    # Fractional random tiebreak in [0,1) on top of the integer weighted-overlap score
    @function_score = {
      functions: [{ random_score: { seed: @post.id, field: "id" } }],
      score_mode: :sum,
      boost_mode: :sum,
    }
  end
end
