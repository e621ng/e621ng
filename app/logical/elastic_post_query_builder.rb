# frozen_string_literal: true

class ElasticPostQueryBuilder < ElasticQueryBuilder
  # Used to determine if a grouped search that wouldn't automatically filter out deleted searches
  # will force other grouped searches to not automatically filter out deleted searches. (i.e. if the
  # `-status:deleted` filter is toggled off globally or only on descendants & ancestors).
  GLOBAL_DELETED_FILTER = true

  ERROR_ON_DEPTH_EXCEEDED = true

  # Must be >= 0; 0 removes all impact of date on rank.
  # The smaller the value, the more shallow the initial curve.
  RANK_EXPONENT = 0.4

  def initialize( # rubocop:disable Metrics/ParameterLists
    query,
    resolve_aliases: true,
    free_tags_count: 0,
    enable_safe_mode: CurrentUser.safe_mode?,
    always_show_deleted: false,
    **kwargs
  )
    @depth = kwargs.fetch(:depth, 0)
    # If it got this far, failing silently didn't work; force error
    raise TagQuery::DepthExceededError if @depth >= TagQuery::DEPTH_LIMIT
    unless query.is_a?(TagQuery)
      query = TagQuery.new(
        query,
        resolve_aliases: resolve_aliases,
        free_tags_count: free_tags_count,
        can_have_groups: true,
        **kwargs,
      )
    end
    @resolve_aliases = resolve_aliases
    @free_tags_count = free_tags_count
    @enable_safe_mode = enable_safe_mode
    @always_show_deleted = always_show_deleted
    @always_show_deleted ||= !query.hide_deleted_posts?(at_any_level: true) if GLOBAL_DELETED_FILTER && @depth <= 0
    @error_on_depth_exceeded = kwargs.fetch(:error_on_depth_exceeded, ERROR_ON_DEPTH_EXCEEDED)
    super(query)
  end

  def model_class
    Post
  end

  def add_tag_string_search_relation(tags)
    must.concat(tags[:must].map { |x| { term: { tags: x } } })
    must_not.concat(tags[:must_not].map { |x| { term: { tags: x } } })
    should.concat(tags[:should].map { |x| { term: { tags: x } } })
  end

  # Adds the grouped subsearches to the query.
  #
  # NOTE: Has the hidden side-effect of updating `always_show_deleted` with each subsearches'
  # `hide_deleted_posts?` at each step in the chain.
  def add_group_search_relation(groups)
    raise TagQuery::DepthExceededError if (@depth + 1) >= TagQuery::DEPTH_LIMIT && @error_on_depth_exceeded
    return if (@depth + 1) >= TagQuery::DEPTH_LIMIT || groups.blank? || (groups[:must].blank? && groups[:must_not].blank? && groups[:should].blank?)
    asd_cache = @always_show_deleted
    cb = ->(x) do
      # If we aren't using a global filter and we haven't already disabled `-status:deleted`
      # auto-insertion, then downstream queries need to be either pre-parsed or analyzed with
      # `should_hide_deleted?` to determine if parents should hide deleted for their children.
      unless GLOBAL_DELETED_FILTER || asd_cache || x.is_a?(TagQuery)
        x = TagQuery.new(
          x,
          resolve_aliases: @resolve_aliases,
          free_tags_count: @free_tags_count + @q.tag_count,
          error_on_depth_exceeded: @error_on_depth_exceeded,
          depth: @depth + 1,
          hoisted_metatags: nil,
          process_groups: true,
        )
      end
      temp = ElasticPostQueryBuilder.new(
        x,
        resolve_aliases: @resolve_aliases,
        free_tags_count: @free_tags_count + @q.tag_count,
        enable_safe_mode: @enable_safe_mode,
        always_show_deleted: GLOBAL_DELETED_FILTER ? true : asd_cache,
        error_on_depth_exceeded: @error_on_depth_exceeded,
        depth: @depth + 1,
        hoisted_metatags: nil,
      )
      @always_show_deleted ||= !temp.innate_hide_deleted_posts? unless GLOBAL_DELETED_FILTER
      temp.create_query_obj(return_nil_if_empty: false)
    end
    must.concat(groups[:must].map(&cb).compact) if groups[:must].present?
    must_not.concat(groups[:must_not].map(&cb).compact) if groups[:must_not].present?
    should.concat(groups[:should].map(&cb).compact) if groups[:should].present?
  end

  def hide_deleted_posts?(at_any_level: !GLOBAL_DELETED_FILTER)
    !(@always_show_deleted || q[:show_deleted] || !q.hide_deleted_posts?(at_any_level: at_any_level))
  end

  def innate_hide_deleted_posts?(at_any_level: !GLOBAL_DELETED_FILTER)
    !(q[:show_deleted] || !q.hide_deleted_posts?(at_any_level: at_any_level))
  end

  # Used to resolve handle the values in `q[:order]`. Each value should be unique; if you want a
  # a new `order` metatag value to match one of these preexisting values, add it in `TagQuery`;
  # otherwise, it won't be in the autocomplete (among other thing).
  ORDER_TABLE = Hash.new({ id: :desc }).merge({
    "id" => [{ id: :asc }],
    "id_desc" => [{ id: :desc }],
    "change" => [{ change_seq: :desc }],
    "change_asc" => [{ change_seq: :asc }],
    "md5" => [{ md5: :desc }],
    "md5_asc" => [{ md5: :asc }],
    "score" => [{ score: :desc }, { id: :desc }],
    "score_asc" => [{ score: :asc }, { id: :asc }],
    "duration" => [{ duration: :desc }, { id: :desc }],
    "duration_asc" => [{ duration: :asc }, { id: :asc }],
    "favcount" => [{ fav_count: :desc }, { id: :desc }],
    "favcount_asc" => [{ fav_count: :asc }, { id: :asc }],
    "created" => [{ created_at: :desc }],
    "created_asc" => [{ created_at: :asc }],
    "updated" => [{ updated_at: :desc }, { id: :desc }],
    "updated_asc" => [{ updated_at: :asc }, { id: :asc }],
    "comment" => [{ commented_at: { order: :desc, missing: :_last } }, { id: :desc }],
    "comment_asc" => [{ commented_at: { order: :asc, missing: :_last } }, { id: :asc }],
    "note" => [{ noted_at: { order: :desc, missing: :_last } }],
    "note_asc" => [{ noted_at: { order: :asc, missing: :_first } }],
    "mpixels" => [{ mpixels: :desc }],
    "mpixels_asc" => [{ mpixels: :asc }],
    "aspect_ratio_asc" => [{ aspect_ratio: :asc }],
    "aspect_ratio" => [{ aspect_ratio: :desc }],
    "filesize" => [{ file_size: :desc }],
    "filesize_asc" => [{ file_size: :asc }],
    "tagcount" => [{ tag_count: :desc }],
    "tagcount_asc" => [{ tag_count: :asc }],
    "comment_bumped" => [{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }],
    "comment_bumped_asc" => [{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }],
    # "random" => [{ _score: :desc }],
  }).freeze.each_value(&:freeze)

  def build
    if @enable_safe_mode
      must.push({ term: { rating: "s" } })
    end

    add_array_range_relation(:post_id, :id)
    add_array_range_relation(:mpixels, :mpixels)
    add_array_range_relation(:ratio, :aspect_ratio)
    add_array_range_relation(:width, :width)
    add_array_range_relation(:height, :height)
    add_array_range_relation(:duration, :duration)
    add_array_range_relation(:score, :score)
    add_array_range_relation(:fav_count, :fav_count)
    add_array_range_relation(:filesize, :file_size)
    add_array_range_relation(:change_seq, :change_seq)
    add_array_range_relation(:date, :created_at)
    add_array_range_relation(:age, :created_at)

    TagCategory::CATEGORIES.each do |category|
      add_array_range_relation(:"#{category}_tag_count", "tag_count_#{category}")
    end

    add_array_range_relation(:post_tag_count, :tag_count)

    TagQuery::COUNT_METATAGS.map(&:to_sym).each do |column|
      if q[column] && (relation = range_relation(q[column], column))
        must.push(relation)
      end
    end

    if q[:md5]
      must.push(match_any(*(q[:md5].map { |m| { term: { md5: m } } })))
    end

    if q[:status] == "pending"
      must.push({ term: { pending: true } })
    elsif q[:status] == "flagged"
      must.push({ term: { flagged: true } })
    elsif q[:status] == "modqueue"
      must.push(match_any({ term: { pending: true } }, { term: { flagged: true } }))
    elsif q[:status] == "deleted"
      must.push({ term: { deleted: true } })
    elsif q[:status] == "active"
      must.push(
        { term: { pending: false } },
        { term: { deleted: false } },
        { term: { flagged: false } },
      )
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_must_not] == "pending"
      must_not.push({ term: { pending: true } })
    elsif q[:status_must_not] == "flagged"
      must_not.push({ term: { flagged: true } })
    elsif q[:status_must_not] == "modqueue"
      must_not.push(match_any({ term: { pending: true } }, { term: { flagged: true } }))
    elsif q[:status_must_not] == "deleted"
      must_not.push({ term: { deleted: true } })
    elsif q[:status_must_not] == "active"
      must.push(match_any(
                  { term: { pending: true } },
                  { term: { deleted: true } },
                  { term: { flagged: true } },
                ))
    end

    add_array_relation(:uploader_ids, :uploader)
    add_array_relation(:approver_ids, :approver, any_none_key: :approver)
    add_array_relation(:commenter_ids, :commenters, any_none_key: :commenter)
    add_array_relation(:noter_ids, :noters, any_none_key: :noter)
    add_array_relation(:note_updater_ids, :noters) # Broken, index field missing
    add_array_relation(:pool_ids, :pools, any_none_key: :pool)
    add_array_relation(:set_ids, :sets)
    add_array_relation(:fav_ids, :faves)
    add_array_relation(:parent_ids, :parent, any_none_key: :parent)

    add_array_relation(:rating, :rating)
    add_array_relation(:filetype, :file_ext)
    add_array_relation(:delreason, :del_reason, action: :wildcard)
    add_array_relation(:description, :description, action: :match_phrase_prefix)
    add_array_relation(:note, :notes, action: :match_phrase_prefix)
    add_array_relation(:sources, :source, any_none_key: :source, action: :wildcard)
    add_array_relation(:deleter, :deleter)
    add_array_relation(:upvote, :upvotes)
    add_array_relation(:downvote, :downvotes)

    q[:voted]&.each do |voter_id|
      must.push(match_any({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } }))
    end

    q[:voted_must_not]&.each do |voter_id|
      must_not.push({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } })
    end

    q[:voted_should]&.each do |voter_id|
      should.push({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } })
    end

    if q[:child] == "none"
      must.push({ term: { has_children: false } })
    elsif q[:child] == "any"
      must.push({ term: { has_children: true } })
    end

    # Handle locks
    q[:locked]&.each { |lock_type| must.push({ term: { "#{lock_type}_locked": true } }) }
    q[:locked_must_not]&.each { |lock_type| must.push({ term: { "#{lock_type}_locked": false } }) }
    q[:locked_should]&.each { |lock_type| should.push({ term: { "#{lock_type}_locked": true } }) }

    # Handle `TagQuery::BOOLEAN_METATAGS`
    if q.include?(:hassource)
      (q[:hassource] ? must : must_not).push({ exists: { field: :source } })
    end

    if q.include?(:hasdescription)
      (q[:hasdescription] ? must : must_not).push({ exists: { field: :description } })
    end

    if q.include?(:ischild)
      (q[:ischild] ? must : must_not).push({ exists: { field: :parent } })
    end

    if q.include?(:isparent)
      must.push({ term: { has_children: q[:isparent] } })
    end

    if q.include?(:inpool)
      (q[:inpool] ? must : must_not).push({ exists: { field: :pools } })
    end

    if q.include?(:pending_replacements)
      must.push({ term: { has_pending_replacements: q[:pending_replacements] } })
    end

    if q.include?(:artverified)
      must.push({ term: { artverified: q[:artverified] } })
    end

    add_tag_string_search_relation(q[:tags])

    # Update always_show_deleted
    @always_show_deleted ||= q[:show_deleted] unless GLOBAL_DELETED_FILTER

    # Use the updated value in groups
    add_group_search_relation(q[:groups])

    # The groups updated our value; now optionally hide deleted
    must.push({ term: { deleted: false } }) if hide_deleted_posts?

    case q[:order] # rubocop:disable Style/MultilineIfModifier,Lint/RedundantCopDisableDirective -- Skipping this is the exception, not the rule.
    # TODO: Add this to the `ElasticPostQueryBuilder::ORDER_TABLE` hash
    when /\A(?<column>#{TagQuery::COUNT_METATAGS.join('|')})(_(?<direction>asc))?\z/i
      direction = Regexp.last_match[:direction] || "desc"
      order.push({ Regexp.last_match[:column] => direction }, { id: direction })

    # TODO: Add this to the `ElasticPostQueryBuilder::ORDER_TABLE` hash
    when /\A(#{TagCategory::SHORT_NAME_REGEX})tags(_asc)?\Z/
      order.push({ -"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => $2 ? :asc : :desc })

    when "hot"
      two_days_ago = 2.days.ago(q[:hot_from] || Time.current)
      @function_score = {
        script_score: {
          script: {
            params: { milliseconds_in_two_days: 172_800_000, two_days_ago: two_days_ago.to_i * 1000 },
            # https://www.desmos.com/calculator/1hffttlyxp
            # a = (doc['created_at'].value.millis - params.two_days_ago)
            # b = (a / params.milliseconds_in_two_days)
            # c = Math.abs(1.0 - b)
            # d = Math.pow(c, #{RANK_EXPONENT})
            # e = (d + 1.0)
            # f = (e / 2.0)
            # score = doc['score'].value * f
            source: "doc['score'].value * ((Math.pow(Math.abs(1.0 - ((doc['created_at'].value.millis - params.two_days_ago) / params.milliseconds_in_two_days)), #{RANK_EXPONENT}) + 1.0) / 2.0)",
          },
        },
      }
      must.push({ range: { score: { gt: 0 } } })
      must.push({ range: { created_at: if q[:hot_from]
                                         { gte: two_days_ago, lte: q[:hot_from] }
                                       else
                                         { gte: two_days_ago }
                                       end } })
      order.push({ _score: :desc })

    when "random"
      order.push({ _score: :desc })
      @function_score = {
        random_score: q[:random_seed].present? ? { seed: q[:random_seed], field: "id" } : {},
        boost_mode: :replace,
      }

    when "comment_bumped", "comment_bumped_asc"
      self.order = ORDER_TABLE[q[:order]]
      must.push({ exists: { field: "comment_bumped_at" } })

    else
      self.order = ORDER_TABLE[q[:order]]
      # Don't add order if nested in a group, as it should have been pulled out prior by `TagQuery#scan_search`.
    end unless @depth > 0

    if !CurrentUser.user.nil? && !CurrentUser.user.is_staff? && Security::Lockdown.hide_pending_posts_for > 0
      # NOTE: As written, it's ambiguous if this is intended to overwrite `ElasticQueryBuilder.should`.
      should = [
        {
          range: {
            created_at: {
              lte: Security::Lockdown.hide_pending_posts_for.hours.ago,
            },
          },
        },
        { term: { pending: false } },
      ]

      unless CurrentUser.user.id.nil?
        should.push({ term: { uploader: CurrentUser.user.id } })
      end

      must.push(match_any(*should))
    end
  end
end
