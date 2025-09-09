# frozen_string_literal: true

class TagQuery
  class CountExceededError < StandardError
    attr_reader :query_obj, :resolve_aliases, :tag_count, :free_tags_count, :kwargs_hash

    def initialize(
      msg = -"You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time",
      query_obj: nil,
      resolve_aliases: nil,
      tag_count: nil,
      free_tags_count: nil
    )
      @query_obj = query_obj
      @resolve_aliases = resolve_aliases
      @tag_count = tag_count
      @free_tags_count = free_tags_count
      @kwargs = {
        query_obj: query_obj,
        resolve_aliases: resolve_aliases,
        tag_count: tag_count,
        free_tags_count: free_tags_count,
      }.freeze
      super(msg)
    end
  end

  class DepthExceededError < StandardError
    attr_reader :query_obj, :resolve_aliases, :tag_count, :free_tags_count, :kwargs_hash, :depth

    def initialize(msg = -"You cannot have more than #{TagQuery::DEPTH_LIMIT} levels of grouping at a time", **kwargs)
      @query_obj = kwargs[:query_obj]
      @resolve_aliases = kwargs[:resolve_aliases]
      @tag_count = kwargs[:tag_count]
      @free_tags_count = kwargs[:free_tags_count]
      @depth = kwargs[:depth]
      @kwargs_hash = kwargs.freeze
      super(msg)
    end
  end

  class InvalidTagError < StandardError
    attr_reader :query_obj, :resolve_aliases, :tag_count, :free_tags_count, :kwargs_hash

    def initialize(msg = "Invalid tag in query", **kwargs)
      msg = "#{kwargs[:tag]}: #{msg}".freeze if kwargs[:tag]
      msg = "#{kwargs[:prefix]}#{msg}" if kwargs[:prefix]
      msg = "#{msg} (Can't have a \"*\" in a tag prefixed with \"~\")" if kwargs[:prefix] == "~" && kwargs[:has_wildcard]
      @tag = kwargs[:tag]
      @prefix = kwargs[:prefix]
      @has_wildcard = kwargs[:has_wildcard]
      @invalid_characters = kwargs[:invalid_characters] || kwargs[:tag]&.scan(kwargs[:prefix] == "~" ? REGEX_VALID_TAG_CHECK : REGEX_VALID_TAG_CHECK_2)
      @query_obj = kwargs[:query_obj]
      @resolve_aliases = kwargs[:resolve_aliases]
      @tag_count = kwargs[:tag_count]
      @free_tags_count = kwargs[:free_tags_count]
      @kwargs_hash = kwargs.freeze
      super(msg)
    end
  end

  COUNT_METATAGS = %w[comment_count].freeze

  # Tags with parsed values of `true` or `false`. See `TagQuery#parse_boolean` for details.
  BOOLEAN_METATAGS = %w[
    hassource hasdescription isparent ischild inpool pending_replacements artverified
  ].freeze

  CATEGORY_METATAG_MAP = TagCategory::SHORT_NAME_MAPPING.to_h { |k, v| [-"#{k}tags", -"tag_count_#{v}"] }.freeze

  NEGATABLE_METATAGS = %w[
    id filetype type rating description parent user user_id approver flagger deletedby delreason
    source status pool set fav favoritedby note locked upvote votedup downvote voteddown voted
    width height mpixels ratio filesize duration score favcount date age change tagcount
    commenter comm noter noteupdater
  ].concat(CATEGORY_METATAG_MAP.keys).freeze

  METATAGS = %w[md5 order limit child randseed hot_from ratinglocked notelocked statuslocked].concat(
    NEGATABLE_METATAGS, COUNT_METATAGS, BOOLEAN_METATAGS
  ).freeze

  # rubocop:disable Layout/HashAlignment -- Better readability for a constant

  # A hashmap of all `order` metatag value aliases that can be inverted by being suffixed by
  # `_desc`/`_asc`, to the input value they represent (`comm` -> `comment`).
  #
  # All keys must map to a value in `TagQuery::ORDER_INVERTIBLE_ROOTS` (e.g. `order:comm` is an alias for `order:comment`).
  #
  # Aliases are used to:
  # 1. Resolve equivalent inputs to a unified output for `ElasticPostQueryBuilder` (e.g. `comm` & `comm_desc` will automatically be converted to `comment`, `comm_asc` will automatically be converted to `comment_asc`)
  # 2. Automatically generate all valid related values for autocomplete (e.g. `comm` will have `comm`, `comm_desc`, & `comm_asc` added to autocomplete)
  ORDER_INVERTIBLE_ALIASES = {
    "created_at"  => "created",
    "updated_at"  => "updated",
    "comm"        => "comment",
    "comm_bumped" => "comment_bumped",
    "comm_count"  => "comment_count",
    "size"        => "filesize",
    "ratio"       => "aspect_ratio",
  }.merge(
    # # Adds `artisttags` -> `arttags`
    # # Removes duplicate `metatags` -> `metatags`
    # CATEGORY_METATAG_MAP.keys.delete_if { |e| e == "metatags" }.index_by do |e|
    #   "#{TagCategory::SHORT_NAME_MAPPING[e.delete_suffix('tags')]}tags"
    # end,

    # If both of the following are added, one must start w/
    # `CATEGORY_METATAG_MAP.keys.delete_if { |e| e == "metatags" }` to remove duplicate cause by the
    # short & long name for `meta` being the same.

    # # Adds `art_tags` -> `arttags`
    # CATEGORY_METATAG_MAP.keys.delete_if { |e| e == "metatags" }.index_by { |e| "#{e.delete_suffix('tags')}_tags" },

    # Adds `artist_tags` -> `arttags`
    CATEGORY_METATAG_MAP.keys.index_by do |e|
      "#{TagCategory::SHORT_NAME_MAPPING[e.delete_suffix('tags')]}_tags"
    end,
  ).freeze

  # A hashmap of all `order` metatag value aliases that can't be inverted by being suffixed by
  # `_desc`/`_asc`, to the input value they represent (e.g. `landscape` -> `aspect_ratio`).
  #
  # All keys must map to a normalized value in `TagQuery::ORDER_METATAGS` (e.g. `order:landscape` is an alias for `order:aspect_ratio`, & `order:aspect_ratio` is equivalent to `order:aspect_ratio_desc`, but `landscape` is mapped solely to `aspect_ratio` & not `aspect_ratio_desc`).
  ORDER_NON_SUFFIXED_ALIASES = {
    "portrait"    => "aspect_ratio_asc",
    "landscape"   => "aspect_ratio",
    "rank"        => "hot",
  }.freeze

  # rubocop:enable Layout/HashAlignment

  # NOTE: The first element (`id`) is the only one whose value is equivalent to the `_asc`-suffixed variant.
  ORDER_INVERTIBLE_ROOTS = %w[
    id score md5 favcount note mpixels filesize tagcount change duration
    created updated comment comment_bumped aspect_ratio
  ].concat(COUNT_METATAGS, CATEGORY_METATAG_MAP.keys).freeze

  # All possible valid values for `order` metatags; used for autocomplete.
  # * With the exception of `random` & `hot`, all values have an option to invert the order.
  # * With the exception of `portrait`/`landscape`, all invertible values have a bare, `_asc`, & `_desc` variant.
  # * With the exception of `id`, all bare invertible values are equivalent to their `_desc`-suffixed counterparts.
  #
  # Add non-reversible entries to the array literal here.
  ORDER_METATAGS = %w[
    random hot
  ].concat(
    ORDER_INVERTIBLE_ALIASES
      .keys.concat(ORDER_INVERTIBLE_ROOTS)
      .flat_map { |str| [str, -"#{str}_desc", -"#{str}_asc"] },
    ORDER_NON_SUFFIXED_ALIASES.keys,
  ).freeze

  # All `order` metatag values to be included in the autocomplete.
  #
  # This is used to cut down on bloat in the autocomplete. All supported values are included in the
  # autocomplete by default, and must be specifically excluded here; this keeps the autocomplete
  # from missing values due to an oversight.
  ORDER_METATAGS_AUTOCOMPLETE = (ORDER_METATAGS - %w[
    id_asc
  ].concat(
    ORDER_INVERTIBLE_ROOTS[1..].map { |e| -"#{e}_desc" }, # Remove superfluous `_desc` suffix from all but `id_desc`
    CATEGORY_METATAG_MAP.keys.map { |e| -"#{e}_desc" }, # Remove superfluous `_desc` suffix
    (ORDER_INVERTIBLE_ALIASES.keys - CATEGORY_METATAG_MAP.keys.map do |e| # Remove all aliased forms...
      "#{TagCategory::SHORT_NAME_MAPPING[e.delete_suffix('tags')]}_tags" # ...for all but the full tag category names
    end).flat_map { |e| [e, -"#{e}_desc", -"#{e}_asc"] },
    CATEGORY_METATAG_MAP.keys.map { |e| "#{TagCategory::SHORT_NAME_MAPPING[e.delete_suffix('tags')]}_tags" }.map { |e| -"#{e}_desc" }, # Remove superfluous `_desc` suffix
    ORDER_NON_SUFFIXED_ALIASES.keys - %w[portrait landscape], # Remove all non-suffixed aliases except `portrait` & `landscape`
    %w[aspect_ratio aspect_ratio_asc], # Remove the forms `portrait` & `landscape` resolve to
    CATEGORY_METATAG_MAP.keys.flat_map { |e| [e, -"#{e}_asc"] }, # Remove the resolved forms of the full tag category forms
  )).freeze

  # Should currently just be `random` & `hot`; not a constant due to only current use being tests.
  def self.order_non_invertible_roots
    (ORDER_METATAGS - ORDER_INVERTIBLE_ALIASES
    .keys.concat(ORDER_INVERTIBLE_ROOTS)
    .flat_map { |str| [str, -"#{str}_desc", -"#{str}_asc"] }
    .concat(ORDER_NON_SUFFIXED_ALIASES.keys)).freeze
  end

  # All values of `TagQuery::ORDER_NON_SUFFIXED_ALIASES` should be in this array.
  # Not a constant due to only current use being tests.
  def self.order_valid_non_suffixed_alias_values
    (order_non_invertible_roots + ORDER_INVERTIBLE_ROOTS[1..]
    .flat_map { |str| [str, -"#{str}_asc"] })
      .push("id", "id_desc")
      .freeze
  end

  # The initial value of a negated `order` metatag mapped to the resultant value.
  # In the general case, tags have a `_asc` suffix appended/removed.
  #
  # NOTE: With the exception of `id_desc`, values ending in `_desc` are equivalent to the same string
  # with that suffix removed; as such, these keys, along with `id_asc`, `random`, & `hot`,
  # are not included in this hash.
  ORDER_VALUE_INVERSIONS = ORDER_INVERTIBLE_ROOTS[1..].flat_map { |str| [str, -"#{str}_asc"] }.push(*ORDER_NON_SUFFIXED_ALIASES.keys, "id", "id_desc").index_with do |e|
    case e
    when "id"        then "id_desc"
    when "id_desc"   then "id"
    when "portrait"  then ORDER_NON_SUFFIXED_ALIASES["landscape"]
    when "landscape" then ORDER_NON_SUFFIXED_ALIASES["portrait"]
    when "rank"      then ORDER_NON_SUFFIXED_ALIASES["rank"]
    else
      raise ArgumentError, -"Unhandled non-invertible alias: #{e}" if ORDER_NON_SUFFIXED_ALIASES.key?(e)
      e.end_with?("_asc") ? e.delete_suffix("_asc") : -"#{e}_asc"
    end
  end.freeze

  # Only these tags hold global meaning and don't have added meaning by being in a grouped context.
  # Therefore, these are pulled out of groups and placed on the top level of searches.
  #
  # Note that this includes all valid prefixes.
  GLOBAL_METATAGS = %w[order -order limit randseed hot_from].freeze

  # The values for the `status` metatag that will override the automatic hiding of deleted posts
  # from search results. Other tags do also alter this behavior; specifically, a `deletedby` or
  # `delreason` metatag.
  OVERRIDE_DELETED_FILTER_STATUS_VALUES = %w[deleted active any all].freeze

  # The metatags that can override the automatic hiding of deleted posts from search results. Note
  # that the `status` metatag alone ***does not*** override filtering; it must also have a value
  # present in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES`.
  #
  # Note that this includes all valid prefixes.
  OVERRIDE_DELETED_FILTER_METATAGS = %w[
    status -status
    delreason -delreason ~delreason
    deletedby -deletedby ~deletedby
  ].freeze

  STATUS_VALUES = %w[all any pending modqueue deleted flagged active].freeze

  # Used for quickly profiling optimizations, tweaking desired behavior, etc. Should be removed
  # after reviews are completed.
  # * `COUNT_TAGS_WITH_SCAN_RECURSIVE` [`false`]: Use `TagQuery.scan_recursive` to increment
  # `@tag_count` in `parse_query`?
  # * `STOP_ON_TAG_COUNT_EXCEEDED` [`true`]: Short-circuit immediately when max tags exceeded?
  # * `EARLY_SCAN_SEARCH_CHECK` [`true`]: Check for a top level query before using the more
  # expensive tokenizer?
  #   * Better if query contains no closing parenthesis aside from the group delimiter, worse
  # otherwise.
  # * `CHECK_GROUP_TAGS_AND_DEPTH` [`"root"`]: Count tags in group & group depth at each step, or
  # allow these checks to occur as groups are recursively processed?
  #   * true: always check
  #   * false: always count as part of the recursive process
  #   * anything else: count at the root
  # * `CHECK_TAG_VALIDITY` [`true`]: don't add invalid tags (as detected by
  # `TagQuery::REGEX_VALID_TAG_CHECK` or a tag w/ `*` starting w/ `~`) to query? If true, the
  # following flag take effect:
  #   * `ERROR_ON_INVALID_TAG` [`true`]: Stop search if tag is invalid?
  #   * `CATCH_INVALID_TAG` [`true`]: If true & `TagQuery::SETTINGS[:ERROR_ON_INVALID_TAG]` is true, will only
  # error out if the invalid tag would cause this level of results to return nothing (i.e. if the
  # invalid tag isn't prefixed by `-` or `~`) and won't let that error propagate; essentially eagerly
  # halts execution of this level of searching.
  # `NO_NON_METATAG_UNLIMITED_TAGS`: Can there be an unlimited tag that isn't a metatag? Used to save some checks in `TagQuery.parse_query`.
  SETTINGS = {
    COUNT_TAGS_WITH_SCAN_RECURSIVE: false,
    STOP_ON_TAG_COUNT_EXCEEDED: true,
    EARLY_SCAN_SEARCH_CHECK: true,
    CHECK_GROUP_TAGS_AND_DEPTH: "root",
    CHECK_TAG_VALIDITY: false,
    ERROR_ON_INVALID_TAG: true,
    CATCH_INVALID_TAG: true,
    NO_NON_METATAG_UNLIMITED_TAGS: true,
  }.freeze

  delegate :[], :include?, to: :@q
  attr_reader :q, :resolve_aliases, :tag_count

  # ### Parameters
  # * `query`
  # * `resolve_aliases` [`true`]
  # * `free_tags_count` [`0`]
  # * `error_on_depth_exceeded` [`false`]
  # * `depth` [`0`]
  def initialize(query, resolve_aliases: true, free_tags_count: 0, **)
    @q = {
      tags: {
        must: [],
        must_not: [],
        should: [],
      },
      show_deleted: false,
    }
    @resolve_aliases = resolve_aliases
    @tag_count = 0
    @free_tags_count = free_tags_count

    if SETTINGS[:CHECK_TAG_VALIDITY] && SETTINGS[:CATCH_INVALID_TAG]
      begin
        parse_query(query, **)
      rescue InvalidTagError
        @q = {
          tags: {
            must: [],
            must_not: [],
            should: [],
          },
          show_deleted: false,
        }
        @tag_count = 0
      end
    else
      parse_query(query, **)
    end
    # raise CountExceededError if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
  end

  def tag_query_limit
    @tag_query_limit ||= Danbooru.config.tag_query_limit - @free_tags_count
  end

  def tag_surplus
    tag_query_limit - @tag_count
  end

  # Increases the tag count by the given `value`, and (conditionally) checks if the new count
  # exceeds the `tag_query_limit`, throwing a `TagQuery::CountExceededError` if so.
  #
  # Only performs the check if `SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED]` is true.
  def increment_tag_count(value)
    @tag_count += value
    raise CountExceededError if SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED] && @tag_count > tag_query_limit
  end

  def is_grouped_search?
    q[:groups].present? && (q[:groups][:must].present? || q[:groups][:must_not].present? || q[:groups][:should].present?)
  end

  # Whether the default behavior to hide deleted posts should be overridden.
  # ### Parameters
  # * `always_show_deleted` [`false`]: The override value. Corresponds to
  # `ElasticPostQueryBuilder.always_show_deleted`.
  # * `at_any_level` [`false`]: Should groups be accounted for, or just this level?
  #
  # ### Returns
  # `true` unless
  # * `always_show_deleted`,
  # * `q[:status]`/`q[:status_must_not]` contains a value in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES`,
  # * One of the following is non-nil:
  #   * `q[:deleter]`/`q[:deleter_must_not]`/`q[:deleter_should]`
  #   * `q[:delreason]`/`q[:delreason_must_not]`/`q[:delreason_should]`, or
  # * If `at_any_level`,
  #   * `q[:children_show_deleted]` is `true`, or
  #   * any of the subsearches in `q[:groups]` return `false` from `TagQuery.should_hide_deleted_posts?`
  #     * This is overridden to return `true` if the subsearches in `q[:groups]` are type `TagQuery`,
  # as preprocessed queries should have had their resultant value elevated to this instance's
  # `q[:children_show_deleted]` during group processing.
  # ### Raises
  # * `RuntimeError`: when `q[:children_show_deleted]` is `nil` & any element in `q[:groups]` is a
  # `TagQuery`, as `q[:children_show_deleted]` shouldn't be `nil` if subsearches were processed.
  def hide_deleted_posts?(always_show_deleted: false, at_any_level: false)
    if always_show_deleted || q[:show_deleted]
      false
    elsif at_any_level
      if q[:children_show_deleted].nil? &&
         q[:groups].present? &&
         [*(q[:groups][:must] || []), *(q[:groups][:must_not] || []), *(q[:groups][:should] || [])].any? { |e| e.is_a?(TagQuery) ? (raise "Invalid State: q[:children_show_deleted] shouldn't be nil if subsearches were processed.") : !TagQuery.should_hide_deleted_posts?(e, at_any_level: true) }
        false
      else
        !q[:children_show_deleted]
      end
    else
      true
    end
  end

  # Guesses whether the default behavior to hide deleted posts should be overridden.
  #
  # If there are any metatags at the specified level that imply deleted posts shouldn't be hidden (even if
  # overridden elsewhere), this will return false.
  #
  # ### Parameters
  # * `query` {String|String[]|TagQuery}:
  # * `always_show_deleted` [`false`]: The override value. Corresponds to
  # `ElasticPostQueryBuilder.always_show_deleted`.
  # * `at_any_level` [`true`]: Should values inside groups be accounted for?
  #
  # ### Returns
  # `false` if `always_show_deleted` or `query` contains either a `delreason`/`deletedby`
  # metatags or a `status` metatag w/ a value in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES` at
  # the specified depth; `true` otherwise.
  def self.should_hide_deleted_posts?(query, always_show_deleted: false, at_any_level: true)
    return false if always_show_deleted
    return query.hide_deleted_posts?(at_any_level: at_any_level) if query.is_a?(TagQuery)
    TagQuery.fetch_metatags(query, *OVERRIDE_DELETED_FILTER_METATAGS, prepend_prefix: false, at_any_level: at_any_level) do |tag, val|
      return false unless tag.delete_prefix("-") == "status" && !val.in?(OVERRIDE_DELETED_FILTER_STATUS_VALUES)
    end
    true
  end

  # Can a ` -status:deleted` be safely appended to the search without changing it's contents?
  def self.can_append_deleted_filter?(query, at_any_level: true)
    !TagQuery.has_metatags?(query, *OVERRIDE_DELETED_FILTER_METATAGS, prepend_prefix: false, at_any_level: at_any_level, has_all: false)
  end

  # Convert an order metatag into it's simplest consistent representation.
  # * Resolves aliases & inversions
  # * Handles quoted values
  # * Doesn't strip whitespace
  # ### Parameters:
  # * `value`
  # * `invert` [`false`]
  # * `processed` [`true`]: is `value` downcased, stripped, & shed of the `order:`/`-order:` prefix?
  def self.normalize_order_value(value, invert: true, processed: true)
    value.downcase! unless processed
    unless processed || !(/\A(-)?order:(.+)\z/ =~ value)
      invert = $1
      value = $2.delete_prefix('"').delete_suffix('"')
    end
    # Remove suffix when superfluous
    value = value.delete_suffix(%w[id_asc id_desc].include?(value) ? "_asc" : "_desc")
    # Resolve all aliases to their root
    # Wouldn't handle `id_desc`, but irrelevant as `id` isn't aliased.
    value = if value.delete_suffix!("_asc")
              -"#{ORDER_NON_SUFFIXED_ALIASES[value] || ORDER_INVERTIBLE_ALIASES[value] || value}_asc"
            else
              ORDER_NON_SUFFIXED_ALIASES[value] || ORDER_INVERTIBLE_ALIASES[value] || value
            end
    # If inverted, resolve inversion
    value = ORDER_VALUE_INVERSIONS[value] || value if invert
    value
  end

  # Convert query into a consistent representation.
  # * Converts to string
  # * Unicode normalizes w/ nfc
  # * Removes leading & trailing whitespace
  # * For each token:
  #   * Converts to lowercase
  #   * Removes leading & trailing whitespace
  #   * Converts interior whitespace to underscores
  #   * Resolves tag aliases
  # * Sorts
  # * Removes duplicates
  # * Joins into a unified string
  def self.normalize(query)
    tags = TagQuery.scan(query)
    tags = tags.map { |t| Tag.normalize_name(t) }
    tags = TagAlias.to_aliased(tags)
    tags.sort.uniq.join(" ")
  end

  # Convert query into a consistent representation while honoring grouping.
  # Recursively:
  # * Converts to string
  # * Unicode normalizes w/ nfc
  # * Removes leading & trailing whitespace
  # * For each token:
  #   * Converts to lowercase
  #   * Removes leading & trailing whitespace
  #   * Converts interior whitespace to underscores
  #   * Resolves tag aliases (if `normalize_tags`)
  # * Sorts
  # * Removes duplicates at that group's top level
  # Then, if `flatten`, Joins into a unified string
  def self.normalize_search(query, normalize_tags: true, flatten: true)
    tags = TagQuery.scan_recursive(
      query,
      flatten: flatten,
      strip_duplicates_at_level: true,
      strip_prefixes: false,
      sort_at_level: true,
      normalize_at_level: normalize_tags,
    )
    flatten ? tags.join(" ") : tags
  end

  R_FRAG_TK = '(?>"{0,2})(?!(?<=")(?=\s|\z))\S+'

  # Properly tokenizes search strings, handling groups & quoted metatags properly.
  # ### [Live Demo](https://regex101.com/r/KfFYz4)
  # ## Groups:
  # * `token`: the full match w/o any surrounding whitespace
  # * `prefix`: -/~, if present
  # * `body`: the tag w/o the leading `prefix` and the trailing whitespace
  #   * `metatag`: if present, the metatag, quoted & unquoted
  #   * `group`: if present, the group, enclosed w/ `(\s+` & `\s)`
  #     * If this is not empty, `metatag` & `tag` may contain matches from inside this group. Only
  # assume a (meta)tag on the top level was matched if this is `nil`.
  #     * `subquery`: the grouped text w/o surrounding whitespace
  #   * `tag`: if the prior 2 weren't present, the following consecutive non-whitespace characters
  #
  # The full match contains leading whitespace + `prefix` + `body` + trailing whitespace
  #
  # If there is a match, one of `metatag`, `group`, or `tag` must be non-nil
  #
  # If `metatag`, `group`, or `tag` is non-nil, it must be non-blank.
  #
  # NOTE: Abuses [zero-length match handling](https://www.regular-expressions.info/zerolength.html)
  # to work. If Ruby's regex engine adjusts how this is handled in a future update, updating to that
  # version may cause properly formatted group queries to fail.
  REGEX_TOKENIZE = /\G(?>\s*)(?<token> # Match any leading whitespace to help with \G
  (?<prefix>[-~])?
  (?<body>
    (?<metatag>(?>\w+:(?>"[^\"]+"(?=\s|\z)|#{R_FRAG_TK})))| # Match a metatag (quoted or not)
    (?<group>(?> #                Match a single group atomically by:
      (?>\(\s+) #                  1. atomically matching a `(` & at least 1 whitespace character
      (?<subquery>(?> #           Greedily find one of the following 2 options
        (?!(?<=\s)\)|(?>\s+)\)) #  2. Skip this option if a `)` that's preceded by whitespace is next
        (?> #                      3. Matching one of the following 3 options once:
          [-~]?\g<metatag>| #       3A. a metatag (to avoid misinterpreting quoted input as groups)
          [-~]?\g<group>| #         3B. a group (to balance parentheses)
          (?> #                     3C. Atomically match either:
            [^\s)]+| #               - 1 or more non-whitespace, non-`)` characters greedily, or
            (?<!\s)\)+ #             - If not preceded by whitespace, 1 or more `)`
          )* #                      Match 3C 0 or more times greedily
        )
        (?>(?>\s+)(?!\)))?| #      4. Atomically match all contiguous whitespace (if present). Or;
        (?=(?<=\s)\)|(?>\s+)\)) #  5. Succeed if the prior char was whitespace and the next is a closing parenthesis. Backtracks the parenthesis. Takes advantage of special handling of zero-length matches.
      )+) #                       If step 5 succeeds, the zero-length match will force the engine to stop trying to match this group.
      (?>\s*)(?<=\s)\) #          Check if preceded by whitespace and match the closing parenthesis.
    )(?=\s|\z))|
    (?<tag>\S+) #                 Match non-whitespace characters (tags)
  ))(?>\s*)/x #                   Match any trailing whitespace to help with \G

  R_FRAG_HG = "(?>[-~]?\\w+:(?>\"[^\"]+\"(?=\\s|\\z)|#{R_FRAG_TK}))".freeze
  # A group existence checker
  REGEX_HAS_GROUP = /\A(?>\s*)(?<main>(?<group>(?>[-~]?\(\s+(?>#{R_FRAG_HG}|[^\s)]+|(?<!\s)\)+|\)(?!\s|\z)|\s+)*(?<=\s)\)(?=\s|\z)))|(?>(?>\s*(?>#{R_FRAG_HG}|[^\s\(]+|\(+(?!\s))\s*)+)\g<main>)/

  # Checks:
  # * Preceded by start of string or whitespace
  # * Optional Prefix
  # * Followed by end of string or whitespace
  # * Starts w/ `(\s`
  # * Ends w/ `\s)`
  #
  # Doesn't check:
  # * If not empty
  # * If enclosed by a quoted metatag
  REGEX_SIMPLE_GROUP_CHECK = /(?<=\s|\A)[-~]?\(\s+(?>\S+|(?>\s+)(?!\)(?>\s|\z)))*\s*\)(?>\s|\z)/

  # Checks:
  # * Preceded by start of string or whitespace
  # * Optional Prefix
  # * Followed by end of string or whitespace
  # * Starts w/ `\w+:"`
  # * Not empty
  # * Ends w/ `"`
  REGEX_ANY_QUOTED_METATAG = /(?<=\s|\A)(?>[-~]?\w+:"[^"]+")(?=\s|\z)/

  # Threshold used for optimizing `TagQuery.has_groups`.
  LONG_QUERY_LENGTH = 200

  def self.has_groups?(tag_str)
    return tag_str.is_grouped_search? if tag_str.is_a?(TagQuery)
    return false if tag_str.blank?
    if tag_str.length > TagQuery::LONG_QUERY_LENGTH
      tag_str.gsub(TagQuery::REGEX_ANY_QUOTED_METATAG, "") if tag_str.include?(':"')
      tag_str.match?(TagQuery::REGEX_SIMPLE_GROUP_CHECK)
    else
      tag_str.match?(TagQuery::REGEX_HAS_GROUP)
    end
  end

  # Iterates through tokens, returning each tokens' `MatchData` in accordance with
  # `TagQuery::REGEX_TOKENIZE`.
  # ### Parameters
  # * `tag_str`
  # * `recurse` [`false`]
  # * `stop_at_group` [`false`]
  # * `compact` [`true`]: Remove `nil` values output by the block (if given) from the return value.
  # * `error_on_depth_exceeded` [`nil`]
  # * `depth` [`0`]
  # #### Block
  # * the associated `MatchData`
  #
  # Return the value to add to the collection.
  # ### Returns
  # An array of results
  # ### Raises
  # * `TagQuery::DepthExceededError`
  def self.match_tokens(tag_str, recurse: false, stop_at_group: false, **kwargs, &)
    depth = kwargs.fetch(:depth, 0)
    if depth >= DEPTH_LIMIT
      raise DepthExceededError if kwargs[:error_on_depth_exceeded]
      return []
    end
    tag_str = tag_str.to_s.unicode_normalize(:nfc).strip
    results = []
    # OPTIMIZE: Candidate for early exit
    # return results if tag_str.blank?

    compact = kwargs.fetch(:compact, true)
    if recurse
      tag_str.scan(REGEX_TOKENIZE) do |_|
        m = Regexp.last_match
        if (!m[:group] || stop_at_group) && ((t = block_given? ? yield(m) : m) || !compact)
          results << t
        end
        if (m = m[:group]&.match(/\A\((?>\s+)(.+)(?<=\s)\)\z/)&.match(1)&.rstrip)
          results.push(*TagQuery.match_tokens(m, **kwargs, recurse: recurse, stop_at_group: stop_at_group, depth: depth + 1, &))
        end
      end
    else
      tag_str.scan(REGEX_TOKENIZE) do |_|
        unless (!stop_at_group && Regexp.last_match[:group]) ||
               (!(t = block_given? ? yield(Regexp.last_match) : Regexp.last_match) && compact)
          results << t
        end
      end
    end
    results
  end

  # Used in `TagQuery.scan_search` to unnest from an all-encompassing unmodified top level group in
  # stripped queries.
  REGEX_PLAIN_TOP_LEVEL_GROUP = /\A(?>\(\s+)((?>[^\s)]+|(?<!\s)\)+|\)+(?!\s|\z)|(?>\s+)(?!\)))+)\s+\)\z/

  # Scan variant that properly handles groups.
  # ### Parameters
  # * `query`
  # * `hoisted_metatags` [`TagQuery::GLOBAL_METATAGS`]: the metatags to lift out of groups to the
  # top level.
  # * `error_on_depth_exceeded` [`false`]
  # * `filter_empty_groups` [`true`]
  # * `preformatted_query` [`nil`]
  # * `delim_metatags` [`true`]
  # * `segregate_metatags` [`nil`]
  # * `force_delim_metatags` [`nil`]
  # #### Recursive Parameters
  # * `depth` [`0`]: must be `>= 0`
  # ### Raises
  # * `TagQuery::DepthExceededError`
  #
  # TODO: * `max_tokens_to_process` [`Danbooru.config.tag_query_limit * 2`]
  #
  # TODO: * `separate_groups` [`nil`]: place groups at the end of the return value to optimize `parse_query`?
  #
  # TODO: * `error_on_count_exceeded` [`false`]
  #
  # TODO: * `free_tags_count` [`false`]
  def self.scan_search(
    query,
    hoisted_metatags: TagQuery::GLOBAL_METATAGS,
    error_on_depth_exceeded: false,
    **kwargs
  )
    depth = 0 unless (depth = kwargs.fetch(:depth, nil)).is_a?(Numeric) && depth >= 0
    return (error_on_depth_exceeded ? (raise DepthExceededError) : []) if depth >= TagQuery::DEPTH_LIMIT
    tag_str = kwargs[:preformatted_query] ? query : query.to_s.unicode_normalize(:nfc).strip
    # Quick exit if given a blank search or a single group w/ an empty search
    return [] if tag_str.blank? || /\A[-~]?\(\s+\)\z/.match?(tag_str)
    # Quick and dirty optimization: If it can't contain any groups, use a simpler tokenizer.
    return TagQuery.send(kwargs[:segregate_metatags] ? :scan_light : :scan, tag_str, **kwargs) unless REGEX_HAS_GROUP.match?(tag_str)
    # If this query is composed of 1 top-level group with no modifiers, convert to ungrouped.
    # TODO: Check if regex catches nested groups & quoted metatag groups
    if SETTINGS[:EARLY_SCAN_SEARCH_CHECK] && tag_str.start_with?("(") && tag_str.end_with?(")")
      if (top = tag_str[REGEX_PLAIN_TOP_LEVEL_GROUP, 1]).present?
        return TagQuery.scan_search(
          top.rstrip,
          **kwargs,
          hoisted_metatags: hoisted_metatags,
          depth: depth + 1,
          error_on_depth_exceeded: error_on_depth_exceeded,
        )
      end
      if (top = REGEX_TOKENIZE.match(tag_str)) && top.end(0) == tag_str.length && top.begin(0) == 0
        return TagQuery.scan_search(
          top[:subquery],
          **kwargs,
          hoisted_metatags: hoisted_metatags,
          depth: depth + 1,
          error_on_depth_exceeded: error_on_depth_exceeded,
        )
      end
    end
    matches = []
    # If segregating, create a separate array to store metatags. Otherwise, make this the same as
    # the non-metatag array; this will mean metatags will be placed in order as usual even w/o a
    # guard clause.
    mts = kwargs[:segregate_metatags] ? [] : matches
    scan_opts = { recurse: false, stop_at_group: true, error_on_depth_exceeded: error_on_depth_exceeded, compact: true }.freeze
    TagQuery.match_tokens(tag_str, **scan_opts) do |m|
      # If it's not a group, move on with this value.
      if m[:group].blank?
        dest = m[:metatag].present? ? mts : matches
        dest << m[:token] unless dest.include?(m[:token])
        next
      end
      # If it's an empty group and we filter those, skip this value.
      next if kwargs.fetch(:filter_empty_groups, true) && m[:subquery].blank?
      # This will change the tag order, putting the hoisted tags in front of the groups that previously contained them
      if hoisted_metatags.present? && m[:subquery]&.match(/(?<=\s|\A)#{hoist_regex_stub ||= "(?>#{hoisted_metatags.join('|')})"}:\S+/)
        cb = ->(sub_match) do
          # if there's a group w/ a hoisted tag,
          if sub_match[:subquery]&.match?(/(?<=\s|\A)#{hoist_regex_stub}:\S+/)
            # rubocop:disable Metrics/BlockNesting
            next error_on_depth_exceeded ? (raise DepthExceededError) : nil if (depth + 1) >= TagQuery::DEPTH_LIMIT
            next kwargs.fetch(:filter_empty_groups, true) ? sub_match[:token] : nil if sub_match[:subquery].blank?
            # rubocop:enable Metrics/BlockNesting
            r_out = "#{TagQuery.match_tokens(sub_match[:subquery], **scan_opts, depth: depth += 1, &cb).uniq.join(' ')} "
            depth -= 1
            next kwargs.fetch(:filter_empty_groups, true) && r_out == " " ? nil : "#{sub_match[:prefix]}( #{r_out})"
          elsif sub_match[:metatag].presence&.match?(/\A#{hoist_regex_stub}:\S+/)
            mts << sub_match[:token] unless mts.include?(sub_match[:token])
            next
          end
          sub_match[:token]
        end
        next (out_v = cb.call(m)).is_a?(Array) ? matches.push(*out_v.uniq) : (matches << out_v unless out_v.nil?)
      end
      matches << m[:token]
    end
    # If segregating metatags & there either are metatags or we're adding the delimiter regardless...
    if kwargs[:segregate_metatags] && (matches.present? || kwargs[:force_delim_metatags])
      (kwargs.fetch(:delim_metatags, true) ? mts << END_OF_METATAGS_TOKEN : mts).concat(matches)
    else # Remember, if `!kwargs[:segregate_metatags]`, this is the same as `matches`, and if not, there is different, but `matches` is empty and we aren't adding the delimiter unless there are non-metatags.
      mts
    end
  end

  REGEX_SIMPLE_SCAN_DELIM = /\G(?>\s*)([-~]?)((?>\w+:(?>"[^"]+"(?=\s|\z)|\S+))|\S+)(?>\s*)/
  REGEX_SIMPLE_SCAN_NON_DELIM = /\G(?>\s*)([-~]?)((?>\w+:(?>"[^"]+"|\S+))|\S+)(?>\s*)/

  # Doesn't account for grouping, but DOES preserve quoted metatag ordering.
  #
  # * `query`
  # * `ensure_delimiting_whitespace` [`true`]: Force quoted metatags to be followed by whitespace,
  # or mimic legacy behavior?
  # * `preformatted_query` [`nil`]
  #
  # OPTIMIZE: Profile variants (including scan_legacy)
  def self.scan(query, **kwargs)
    out = []
    (kwargs[:preformatted_query] ? query : query.to_s.unicode_normalize(:nfc).strip)
      .presence
      &.scan(kwargs.fetch(:ensure_delimiting_whitespace, true) ? REGEX_SIMPLE_SCAN_DELIM : REGEX_SIMPLE_SCAN_NON_DELIM) { |_| out << "#{$1}#{$2}" }
    out.uniq
  end

  REGEX_SCAN_LIGHT_DELIM = /(?<=\s|\A)[-~]?\w+:(?>"[^"]+"(?=\s|\z)|\S+)/
  REGEX_SCAN_LIGHT_NON_DELIM = /[-~]?\w+:(?>"[^"]+"|\S+)/

  # A token that is impossible to input normally that signals to `TagQuery#parse_query` that the
  # leading run of metatags is over to allow it to skip extra processing.
  #
  # NOTE: This is impossible for users to replicate b/c a token starting w/ " won't preserve whitespace
  END_OF_METATAGS_TOKEN = '"END OF METATAGS"'

  # Doesn't account for grouping, places metatags in front.
  #
  # * `query`
  # * `ensure_delimiting_whitespace` [`true`]: Force quoted metatags to be followed by whitespace,
  # or mimic legacy behavior?
  # * `preformatted_query` [`nil`]
  # * `delim_metatags` [`true`]
  # * `force_delim_metatags` [`nil`]
  #
  # OPTIMIZE: Profile variants (including scan_legacy)
  def self.scan_light(query, **kwargs)
    tagstr = (kwargs[:preformatted_query] ? query : query.to_s.unicode_normalize(:nfc).strip)
    mts = []
    tagstr = tagstr.gsub(kwargs.fetch(:ensure_delimiting_whitespace, true) ? REGEX_SCAN_LIGHT_DELIM : REGEX_SCAN_LIGHT_NON_DELIM) do |match|
      mts << match
      ""
    end
    if tagstr.present?
      mts << END_OF_METATAGS_TOKEN if kwargs.fetch(:delim_metatags, true) && (!mts.empty? || kwargs[:force_delim_metatags])
      mts.concat(tagstr.split.uniq)
    elsif kwargs.fetch(:delim_metatags, true) && kwargs[:force_delim_metatags]
      mts << END_OF_METATAGS_TOKEN
    else
      mts
    end
  end

  REGEX_SCAN_LEGACY_QUOTED_METATAGS = /[-~]?\w*?:".*?"/

  # Legacy scan variant which doesn't:
  # * account for grouping
  # * preserve quoted metatag ordering
  # * require either whitespace or the end of input after quoted metatags
  def self.scan_legacy(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    quote_delimited = []
    tagstr = tagstr.gsub(REGEX_SCAN_LEGACY_QUOTED_METATAGS) do |match|
      quote_delimited << match
      ""
    end
    quote_delimited + tagstr.split.uniq
  end

  # * `matches` {`Array`}
  # * `prefix` {`String`}
  # * `strip_prefixes` {`boolean`}:
  # * `delimit_groups` [`true`]
  private_class_method def self.handle_top_level(matches, prefix, strip_prefixes:, **kwargs)
    if kwargs.fetch(:delimit_groups, true)
      matches.insert(0, "#{strip_prefixes ? '' : prefix.presence || ''}(") << ")"
      kwargs.fetch(:flatten) ? matches : [matches]
    elsif !strip_prefixes && prefix.present?
      # NOTE: What should be done when not stripping/distributing modifiers & not delimiting groups?
      # Either place the modifier alone outside the array or inside the array?
      # This won't correctly reconstitute the original string without dedicated code.
      # Currently places alone inside if flattening and outside otherwise
      # If flattening and not delimiting, modifier application is unable to be determined,
      # so remove entirely? Change options to force validity or split into 2 methods?
      kwargs.fetch(:flatten) ? matches.insert(0, prefix) : [prefix, matches]
    else
      kwargs.fetch(:flatten) ? matches : [matches]
    end
  end

  # Scans the given string and processes any groups within recursively.
  #
  # ### Parameters
  # * `query`: the string to scan. Will be converted to a string, normalized, and stripped.
  # * `flatten` [`true`]: Flatten sub-groups into 1 single-level array?
  # * `strip_prefixes` [`false`]
  # * `distribute_prefixes` {`falsy | Array`} [`nil`]: If responds to `<<`, `slice!`, & `includes?`,
  # will be used in recursive calls to store the prefix of the enclosing group; if falsy, prefixes
  # will not be distributed.
  # * `strip_duplicates_at_level` [`false`]: Removes any duplicate tags at the current level, and
  # recursively do the same for each group.
  # * `delimit_groups` [`true`]: Surround groups w/ parentheses elements. Unless `strip_prefixes` or
  # `distribute_prefixes` are truthy, preserves prefix.
  # * `sort_at_level` [`false`]
  # * `normalize_at_level` [`false`]: Call `TagQuery.normalize_single_tag` on each tag token?
  # * `error_on_depth_exceeded` [`false`]
  # * `discard_group_prefix` [`nil`]
  # #### Recursive Parameters (SHOULDN'T BE USED BY OUTSIDE METHODS)
  # * `depth` [0]: Tracks recursive depth to prevent exceeding `TagQuery::DEPTH_LIMIT`
  # ### Raises
  # * `TagQuery::DepthExceededError`
  def self.scan_recursive(
    query,
    flatten: true,
    strip_prefixes: false,
    distribute_prefixes: nil,
    **kwargs
  )
    kwargs[:depth] = (depth = 1 + kwargs.fetch(:depth, -1))
    if depth >= TagQuery::DEPTH_LIMIT
      return raise DepthExceededError if kwargs[:error_on_depth_exceeded]
      return handle_top_level(
        [], distribute_prefixes && !kwargs[:discard_group_prefix] ? distribute_prefixes.slice!(-1) : nil,
        flatten: flatten, strip_prefixes: strip_prefixes, **kwargs
      )
    end
    tag_str = query.to_s.unicode_normalize(:nfc).strip
    # OPTIMIZE: Candidate for early exit
    # return [] if tag_str.blank?

    matches = []
    last_group_index = -1
    group_ranges = [] if flatten
    top = flatten ? [] : nil
    TagQuery.match_tokens(tag_str, recurse: false, stop_at_group: true) do |m| # rubocop:disable Metrics/BlockLength
      # If this query is composed of 1 top-level group (with or without modifiers), handle that here
      if m.end(:group) == tag_str.length && m.begin(:group) <= 1
        distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
        matches = if depth >= TagQuery::DEPTH_LIMIT
                    []
                  else
                    TagQuery.scan_recursive(
                      # m[:body][/\A\(\s+\)\z/] ? "" : m[:body][/\A\(\s+(.*)\s+\)\z/, 1],
                      m[:subquery],
                      flatten: flatten, strip_prefixes: strip_prefixes,
                      distribute_prefixes: distribute_prefixes, **kwargs
                    )
                  end
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
        return handle_top_level(
          matches, kwargs[:discard_group_prefix] ? "" : m[:prefix],
          flatten: flatten, strip_prefixes: strip_prefixes, **kwargs
        )
      elsif m[:group].present?
        kwargs[:depth] -= 1
        value = TagQuery.scan_recursive(
          m[:token], # m[0].strip,
          flatten: flatten, strip_prefixes: strip_prefixes, distribute_prefixes: distribute_prefixes,
          **kwargs
        )
        kwargs[:depth] += 1
        is_duplicate = false
        if kwargs[:strip_duplicates_at_level]
          dup_check = ->(e) { e.empty? ? value.empty? : e.difference(value).blank? }
          if flatten
            matches.each_cons(value.length) { |e| break if (is_duplicate = dup_check.call(e)) } # rubocop:disable Metrics/BlockNesting
          else
            is_duplicate = matches.any?(&dup_check)
          end
        end
        unless is_duplicate
          # splat regardless of flattening to correctly de-nest value
          if kwargs[:sort_at_level]
            group_ranges << ((last_group_index + 1)..(last_group_index + value.length)) if flatten # rubocop:disable Metrics/BlockNesting
            matches.insert(last_group_index += value.length, *value)
          else
            matches.push(*value)
          end
        end
      else
        distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
        prefix = strip_prefixes ? "" : resolve_distributed_tag(distribute_prefixes).presence || m[:prefix] || ""
        value = prefix + (kwargs[:normalize_at_level] ? normalize_single_tag(m[:body]) : m[:body])
        unless kwargs[:strip_duplicates_at_level] && (top || matches).include?(value)
          matches << value
          top << value if top
        end
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
      end
    end
    if kwargs[:sort_at_level]
      if last_group_index >= 0
        pre = matches.slice!(0, last_group_index + 1)
        pre = flatten ? group_ranges.map { |e| pre.slice(e) }.sort!.flatten! : pre.sort
      end
      matches.sort!
      matches.insert(0, *pre) if last_group_index >= 0
    end
    matches
  end

  private_class_method def self.resolve_distributed_tag(distribution)
    return "" if distribution.blank?
    distribution.include?("-") ? "-" : distribution[-1]
  end

  # Searches through the given `query` & finds instances of the given `metatags` in the order they
  # appear in the search.
  #
  # ### Parameters
  # * `query` { `String` }
  # * `metatags` { `String`s | :any }: The metatags to search for. Pass `:any` to match all metatags.
  # * `initial_value` [`nil`]: The first value passed to block; returned if no matches are found.
  # * `prepend_prefix` [`false`]: Match the tags w/ any prefix (e.g. `-status` instead of `status`)?
  # Defaults to only matching the explicitly specified prefix-metatag combinations.
  #
  # #### Block:
  # * `preceding_unmatched_range`
  # * `matched_range`
  # * `pre`: the unmatched text between the start/last match and the current match
  # * `contents`: the entire matched metatag, including its name & leading/trailing double quotes
  # * `post`: the remaining text to test
  # * `tag`: the matched tag name (e.g. `order`, `status`)
  # * `current_value`: the last value output from this block or, if this is the first time
  # the block was called, `initial_value`.
  # * `value`: the value of this metatag. If quoted, quotes have been removed.
  # * `prefix`: if `prepend_prefix`, the matched prefix.
  #
  # Return the new accumulated value.
  #
  # ### Returns
  #   * if matched, the final value generated by the block (if given) or an array of `contents`
  #   * else, `initial_value`
  #
  # Due to the nature of the grouping syntax, special handling for nested metatags in this method is
  # unnecessary. If this changes to a (truly) recursive search implementation, a
  # `TagQuery::DepthExceededError` must be raised when appropriate.
  #
  # NOTE: This method currently does *not* effectively guard against bad input in `metatags`.
  # If an invalid metatag name (e.g. one that contains non-word characters) is passed as input
  # (especially if `prepend_prefix` is falsy), and query contains a *non-quoted* instance of it,
  # that will be matched, even though it will not be processed as a valid metatag in `parse_query`.
  # Since it is highly unlikely such an invalid metatag will be present, guarding against this was
  # deemed unnecessary.
  def self.scan_metatags(query, *metatags, initial_value: nil, prepend_prefix: false, &)
    return initial_value if metatags.blank? || (query = query.to_s.unicode_normalize(:nfc).strip).blank?
    prefix = "([-~]?)" if prepend_prefix
    mts = if metatags.include?(:any)
            '(?>\w+)'
          else
            metatags.inject(nil) { |p, e| "#{p ? "#{p}|" : ''}#{e.to_s.strip}" if e.present? }
          end
    last_index = 0
    on_success = ->(curr_match) do
      if block_given?
        kwargs_hash = if prepend_prefix
                        { prefix: curr_match[1], tag: curr_match[2], value: curr_match[3] || "" }
                      else
                        { tag: curr_match[1], value: curr_match[2] || "" }
                      end
        initial_value = yield(
          preceding_unmatched_range: last_index...(last_index + curr_match.begin(0)),
          matched_range: (last_index + curr_match.begin(0))...(last_index + curr_match.end(0)),
          pre: query[0...(last_index + curr_match.begin(0))],
          contents: curr_match[0],
          post: query[(last_index + curr_match.end(0))..],
          **kwargs_hash,
          current_value: initial_value)
      else
        initial_value = [] unless initial_value.respond_to?(:<<)
        initial_value << curr_match[0]
      end
      last_index += curr_match.end(0)
    end
    plus_one = nil
    # For each quoted metatag, match all the non-quoted queried metatags between the end of the last
    # quoted metatag and the start of this one, then check and process this quoted metatag.
    #
    # If there's no (more) quoted metatags, then just search each metatag between the last index and the end.
    while (quoted_m = query[last_index...query.length].presence&.match(REGEX_ANY_QUOTED_METATAG)) || (!plus_one && (plus_one = true)) # rubocop:disable Lint/LiteralAssignmentInCondition
      # If there are non-quoted matches before current quoted & current quoted doesn't match, manual
      # update of last index requires the offset quoted_m was found with.
      prior_last_index = last_index
      # IDEA: Prevent bad input (e.g. `metatags = ['"precededByDoubleQuote']`) from matching bad tags?
      while (m = query[last_index...(quoted_m&.begin(0)&.send(:+, prior_last_index) || query.length)].presence&.match(/(?<=\s|\A)#{prefix}(#{mts}):(?!""(?>\s|\z))((?>\S+))(?<!")/i))
        on_success.call(m)
      end
      if quoted_m
        # Check if the quoted metatag matches the searched queries (& fix match offsets for `on_success`).
        if (m = query[last_index...(prior_last_index + quoted_m.end(0))].match(/(?<=\s|\A)#{prefix}(#{mts}):"([^"]+)"/i))
          on_success.call(m)
        else # Manually update `last_index` since `on_success` didn't do it.
          last_index = prior_last_index + quoted_m.end(0)
        end
      else
        break
      end
    end
    initial_value
  end

  def self.has_metatag?(tags, *, prepend_prefix: false, at_any_level: true)
    fetch_metatag(tags, *, prepend_prefix: prepend_prefix, at_any_level: at_any_level).present?
  end

  # Pulls the value from the first of the specified metatags found.
  #
  # ### Parameters
  # * `tags` {`String` | `String[]`}: The content to search through.
  # * `metatags`: The metatags to search. Must exactly match. Modifiers aren't accounted for (i.e.
  # `status` won't match `-status` & vice versa).
  # * `at_any_level` [`true`]: Search through groups?
  # * `prepend_prefix` [`false`]: Match the tags w/ any prefix (e.g. `-status` instead of `status`)?
  # Defaults to only matching the explicitly specified prefix-metatag combinations.
  #
  # ### Returns
  # The first instance of `metatags` that is `present?` after leading and trailing double quotes are
  # removed (matching the behavior of `parse_query`). If none are found, returns `nil`.
  #
  # NOTE: For metatags that overwrite their value if repeated (e.g. `status`), this is not
  # representative of the final functional value.
  # If this is a concern, use `TagQuery.fetch_metatags`.
  def self.fetch_metatag(tags, *metatags, at_any_level: true, prepend_prefix: false)
    return nil if tags.blank?

    if tags.is_a?(String)
      if at_any_level
        scan_metatags(tags, *metatags, prepend_prefix: prepend_prefix) { |**kwargs| return kwargs[:value] }
      else
        match_tokens(tags, recurse: false, stop_at_group: false) do |tag|
          next unless tag[:metatag]
          metatag_name, value = tag[:metatag].split(":", 2)
          return value.delete_prefix('"').delete_suffix('"') if metatags.include?(metatag_name)
        end
      end
    elsif at_any_level
      # IDEA: See if checking and only sifting through grouped tags is substantively faster than sifting through all of them
      scan_metatags(tags.join(" "), *metatags, prepend_prefix: prepend_prefix) { |**kwargs| return kwargs[:value] }
    else
      tags.find do |tag|
        metatag_name, value = tag.split(":", 2)
        if metatags.include?(metatag_name)
          value = value.delete_prefix('"').delete_suffix('"') if value.is_a?(String)
          return value if value.present?
        end
      end
    end
  end

  def self.has_metatags?(tags, *metatags, at_any_level: true, prepend_prefix: false, has_all: true)
    r = fetch_metatags(tags, *metatags, prepend_prefix: prepend_prefix, at_any_level: at_any_level)
    r.present? && metatags.send(has_all ? :all? : :any?, &->(mt) { r.key?(mt) })
  end

  # Pulls the values from the specified metatags.
  #
  # ### Parameters
  # * `tags` {`String` | `String[]`}: The content to search through.
  # * `metatags`: The metatags to search. Must exactly match. Modifiers aren't accounted for (i.e.
  # `status` won't match `-status` & vice versa).
  # * `at_any_level` [true]: Search through groups?
  # * `prepend_prefix` [`false`]: Match the tags w/ any prefix (e.g. `-status` instead of `status`)?
  # Defaults to only matching the explicitly specified prefix-metatag combinations.
  #
  # #### Block
  # Called every time a metatag is matched to a non-`blank?` value.
  #
  # * `metatag`: the metatag that was matched.
  # * `value`: the matched value. Leading and trailing double quotes will be removed (matching the
  # behavior of `parse_query`)
  #
  # Yields the value to be added to the result for this match.
  #
  # ### Returns
  # A hash with `metatags` as the keys & an array of either the output of block or the found
  # instances that are `present?`. Leading and trailing double quotes will be removed (matching the
  # behavior of `parse_query`). If none are found for a metatag, that key won't be included in the
  # hash.
  def self.fetch_metatags(tags, *metatags, at_any_level: true, prepend_prefix: false)
    return {} if tags.blank?

    ret_val = {}
    if tags.is_a?(String)
      if at_any_level
        scan_metatags(tags, *metatags, prepend_prefix: prepend_prefix) do |tag:, value:, **|
          ret_val[tag] ||= []
          ret_val[tag] << (block_given? ? yield(tag, value) : value)
        end
      else
        match_tokens(tags, recurse: false, stop_at_group: false) do |token|
          next unless token[:metatag]
          tag, value = token[:metatag].split(":", 2)
          ret_val[tag] ||= []
          ret_val[tag] << (block_given? ? yield(tag, value) : value)
          nil
        end
      end
    elsif at_any_level
      # IDEA: See if checking and only sifting through grouped tags is substantively faster than sifting through all of them
      scan_metatags(tags.join(" "), *metatags, prepend_prefix: prepend_prefix) do |tag:, value:, **|
        ret_val[tag] ||= []
        ret_val[tag] << (block_given? ? yield(tag, value) : value)
      end
    else
      tags.each do |token|
        tag, value = token.split(":", 2)
        next unless metatags.include?(tag)
        value = value.delete_prefix('"').delete_suffix('"') if value.is_a?(String)
        next if value.blank?
        ret_val[tag] ||= []
        ret_val[tag] << (block_given? ? yield(tag, value) : value)
      end
    end
    ret_val
  end

  def self.has_tag?(source_array, *, recurse: true, error_on_depth_exceeded: false)
    TagQuery.fetch_tags(source_array, *, recurse: recurse, error_on_depth_exceeded: error_on_depth_exceeded).any?
  end

  def self.fetch_tags(source_array, *tags_to_find, recurse: true, error_on_depth_exceeded: false)
    if recurse
      source_array.flat_map do |e|
        temp = (e.respond_to?(:join) ? e.join(" ") : e.to_s).strip
        if temp.match(/\A[-~]?\(\s.+\s\)\z/)
          TagQuery.scan_recursive(
            temp,
            strip_duplicates_at_level: true,
            delimit_groups: false,
            distribute_prefixes: false,
            strip_prefixes: false,
            flatten: true,
            error_on_depth_exceeded: error_on_depth_exceeded,
          ).select { |e2| tags_to_find.include?(e2) }
        elsif tags_to_find.include?(e)
          e
        end
      end.compact
    else
      tags_to_find.select { |tag| source_array.include?(tag) }
    end.uniq
  end

  # Takes an array of tokens (groups are also tokenized) and finds which of
  # `Danbooru.config.ads_keyword_tags` are included.
  # ### Returns
  # The relevant tags in a ` `-separated string.
  def self.ad_tag_string(tag_array)
    TagQuery.fetch_tags(tag_array, *Danbooru.config.ads_keyword_tags).join(" ")
  end

  private_class_method def self.normalize_single_tag(tag)
    TagAlias.active.where(antecedent_name: (tag = Tag.normalize_name(tag)))&.first&.consequent_name || tag
  end

  private

  METATAG_SEARCH_TYPE = Hash.new(:must).merge({
    "-" => :must_not,
    "~" => :should,
  }).freeze

  # The maximum number of nested groups allowed before either cutting off processing or triggering a
  # `TagQuery::DepthExceededError`.
  DEPTH_LIMIT = 10

  def pq_check_group_tags?(depth)
    SETTINGS[:CHECK_GROUP_TAGS_AND_DEPTH] == true || (SETTINGS[:CHECK_GROUP_TAGS_AND_DEPTH] != false && depth <= 0)
  end

  def pq_count_tags(group, depth, error_on_depth_exceeded: true)
    if SETTINGS[:COUNT_TAGS_WITH_SCAN_RECURSIVE]
      TagQuery.scan_recursive(
        group,
        flatten: true, delimit_groups: false, strip_prefixes: true, depth: depth + 1,
        strip_duplicates_at_level: false, error_on_depth_exceeded: error_on_depth_exceeded
      ).count { |token| !Danbooru.config.is_unlimited_tag?(token) }
    else
      delta = 0
      TagQuery.match_tokens(
        group,
        recurse: true,
        stop_at_group: false,
        error_on_depth_exceeded: true,
        depth: depth + 1,
      ) do |token|
        next if (!SETTINGS[:NO_NON_METATAG_UNLIMITED_TAGS] || token[:metatag]) && Danbooru.config.is_unlimited_tag?(token[:token])
        if SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED] && delta + 1 + @tag_count > tag_query_limit
          raise CountExceededError
        else
          delta += 1
        end
      end
      delta
    end
  end

  # ### Parameters
  # * `query`
  # * `process_groups` [`false`]: Recursively handle groups?
  # * `error_on_depth_exceeded` [`false`]: Fail silently on depth exceeded?
  # * `can_have_groups` [`true`]: Are groups enabled for this search?
  #   * Used to optimize searches that cannot contain groups by using a simpler scanner and skipping
  # group parsing. Passing this in also disables group processing.
  #
  # ### Notes
  # * Quoted metatags aren't distinguished from non-quoted metatags nor standard tags in
  # `TagQuery.parse_query`; to ensure consistency, even malformed metatags must have leading and
  # trailing double quotes removed.
  #
  # IDEA: Put metatags at end of results instead of beginning (faster if `tag_query_limit` is exceeded)
  # * No extra processing for metatags
  # * Assuming all unlimited tags are metatags, only the metatags at the end would need to be checked.
  #
  # IDEA: Sort groups like metatags
  def parse_query(query, depth: 0, **kwargs)
    return if (query = query.to_s.unicode_normalize(:nfc).strip.freeze).blank?
    can_have_groups = kwargs.fetch(:can_have_groups, true) && TagQuery.has_groups?(query)
    out_of_metatags = false
    params = { preformatted_query: true, ensure_delimiting_whitespace: true, compact: true, force_delim_metatags: true, segregate_metatags: true, delim_metatags: true }.freeze
    if can_have_groups # rubocop:disable Metrics/BlockLength
      TagQuery.scan_search(query, **kwargs, depth: depth, **params)
    else
      TagQuery.scan_light(query, **params)
    end.each do |token|
      # If we're past the starting run of metatags
      if out_of_metatags
        # If there's a non-empty group, correctly increment tag_count, then stop processing/recursively process this token.
        if can_have_groups && (match = /\A([-~]?)\(\s+(.+)(?<!\s)\s+\)\z/.match(token))
          group = match[2]
          increment_tag_count(if kwargs[:process_groups]
                                (begin
                                  group = TagQuery.new(
                                    group,
                                    **kwargs,
                                    free_tags_count: @tag_count + @free_tags_count,
                                    resolve_aliases: @resolve_aliases,
                                    hoisted_metatags: nil, depth: depth + 1
                                  )
                                # rubocop:disable Metrics/BlockNesting
                                rescue CountExceededError
                                  raise CountExceededError.new(query_obj: self)
                                rescue DepthExceededError
                                  raise DepthExceededError.new(query_obj: self)
                                rescue InvalidTagError
                                  raise InvalidTagError.new(query_obj: self)
                                end
                                  # rubocop:enable Metrics/BlockNesting
                                ).tag_count
                              elsif pq_check_group_tags?(depth)
                                pq_count_tags(group, depth, error_on_depth_exceeded: kwargs.fetch(:error_on_depth_exceeded, true))
                              else
                                0
                              end)
          next if group.blank?
          q[:children_show_deleted] ||= !group.hide_deleted_posts?(at_any_level: true) if kwargs[:process_groups]
          q[:groups] ||= {}
          search_type = METATAG_SEARCH_TYPE[match[1]]
          q[:groups][search_type] ||= []
          q[:groups][search_type] << group
        else
          # If `SETTINGS[:NO_NON_METATAG_UNLIMITED_TAGS]` is true, only metatags can be unlimited in
          # `Danbooru.config.is_unlimited_tag?`, so don't bother checking
          increment_tag_count 1 unless !SETTINGS[:NO_NON_METATAG_UNLIMITED_TAGS] && Danbooru.config.is_unlimited_tag?(token)
          add_tag(token)
        end
        next
      # If this is the separator token, discard it and set the flag.
      elsif (out_of_metatags = (token == TagQuery::END_OF_METATAGS_TOKEN))
        next
      end
      # IDEA: Place after quote removal to have `status:deleted` & `status:"deleted"` both be unlimited (with default `is_unlimited_tag?` impl.)
      increment_tag_count 1 unless Danbooru.config.is_unlimited_tag?(token)

      # If it got here, it must be a potentially valid metatag w/o an empty body, so don't check.
      metatag_name, g2 = token.split(":", 2)

      # Remove quotes from description:"abc def"
      g2 = g2.delete_prefix('"').delete_suffix('"')

      type = METATAG_SEARCH_TYPE[metatag_name[0]]
      # IDEA: Use jump table(s) instead
      # * Can use different table depending on value of `type` to reduce comparisons
      # * A hash has faster lookup than sequentially checking cases, and this already maps to a jump table pretty well.
      #   * Almost all of these values already map directly to 1-6 `String` value(s) anyway (and the
      # remainder easily could), so there's little benefit in delegating to `clause.===(metatag_name.downcase)`
      #   * These cases all have the same 2 lightweight dependencies (`type` & `g2`), and by adding
      # `self` as a dependency (and using `Kernel#send` to call helper methods like `TagQuery#add_to_query`
      # if the table is in a different class) we can separate each case from their context easily
      # * It would allow for more precise testing using [Mock#expects](https://www.rubydoc.info/gems/mocha/Mocha/Mock#expects-instance_method)
      # * We could have this block be under the 25 line limit of Metrics/BlockLength
      case metatag_name.downcase
      when "user", "-user", "~user" then add_to_query(type, :uploader_ids, user_id_or_invalid(g2))

      # NOTE: This doesn't match the behavior of `User.name_or_id_to_id`, as that ensures an integral, whereas this will convert leading digits of a non-numeric string.
      when "user_id", "-user_id", "~user_id" then add_to_query(type, :uploader_ids, g2.to_i)

      when "approver", "-approver", "~approver"
        add_to_query(type, :approver_ids, g2, any_none_key: :approver) { user_id_or_invalid(g2) }

      when "commenter", "-commenter", "~commenter", "comm", "-comm", "~comm"
        add_to_query(type, :commenter_ids, g2, any_none_key: :commenter) { user_id_or_invalid(g2) }

      when "noter", "-noter", "~noter"
        add_to_query(type, :noter_ids, g2, any_none_key: :noter) { user_id_or_invalid(g2) }

      when "noteupdater", "-noteupdater", "~noteupdater"
        add_to_query(type, :note_updater_ids, user_id_or_invalid(g2))

      # IDEA: Check which is faster, `inpool:true` & `inpool:false` or `pool:any`/`-pool:none` & `pool:none`/`-pool:any`, and map 1 to the other.
      # They resolve down to the same thing in `ElasticQueryBuilder`/`ElasticPostQueryBuilder`
      # (`must`(`_not`)`.push({ exists: { field: :pools } })`), & `PostQueryBuilder` ~~formerly~~
      # only checked `q[:pool]`, and only for any/none
      when "pool", "-pool", "~pool"
        add_to_query(type, :pool_ids, g2, any_none_key: :pool) { Pool.name_to_id(g2) }

      when "set", "-set", "~set"
        add_to_query(type, :set_ids) do
          post_set_id = PostSet.name_to_id(g2)
          post_set = PostSet.find_by(id: post_set_id)

          next -1 unless post_set # next 0 unless post_set
          raise User::PrivilegeError unless post_set.can_view?(CurrentUser.user)

          post_set_id
        end

      when "fav", "-fav", "~fav", "favoritedby", "-favoritedby", "~favoritedby"
        add_to_query(type, :fav_ids) do
          favuser = User.find_by_name_or_id(g2) # rubocop:disable Rails/DynamicFindBy

          next -1 unless favuser # next 0 unless favuser
          raise Favorite::HiddenError if favuser.hide_favorites?

          favuser.id
        end

      when "md5" then q[:md5] = g2.downcase.split(",")[0..99]

      when "rating", "-rating", "~rating" then add_to_query(type, :rating, g2) if %w[s q e].include?(g2 = g2[0]&.downcase)

      when "locked", "-locked", "~locked"
        add_to_query(type, :locked, g2) if (g2 = case g2.downcase
                                                 when "rating" then :rating
                                                 when "note", "notes" then :note
                                                 when "status" then :status
                                                 end)

      when "ratinglocked" then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked, :rating)
      when "notelocked"   then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked, :note)
      when "statuslocked" then add_to_query(parse_boolean(g2) ? :must : :must_not, :locked, :status)

      when "id", "-id", "~id" then add_to_query(type, :post_id, ParseValue.range(g2))

      when "width", "-width", "~width" then add_to_query(type, :width, ParseValue.range(g2))

      when "height", "-height", "~height" then add_to_query(type, :height, ParseValue.range(g2))

      when "mpixels", "-mpixels", "~mpixels" then add_to_query(type, :mpixels, ParseValue.range_fudged(g2, :float))

      when "ratio", "-ratio", "~ratio" then add_to_query(type, :ratio, ParseValue.range(g2, :ratio))

      when "duration", "-duration", "~duration" then add_to_query(type, :duration, ParseValue.range(g2, :float))

      when "score", "-score", "~score" then add_to_query(type, :score, ParseValue.range(g2))

      when "favcount", "-favcount", "~favcount" then add_to_query(type, :fav_count, ParseValue.range(g2))

      when "filesize", "-filesize", "~filesize" then add_to_query(type, :filesize, ParseValue.range_fudged(g2, :filesize))

      when "change", "-change", "~change" then add_to_query(type, :change_seq, ParseValue.range(g2))

      when "source", "-source", "~source"
        add_to_query(type, :sources, g2, any_none_key: :source, wildcard: true) { "#{g2}*" }

      when "date", "-date", "~date" then add_to_query(type, :date, ParseValue.date_range(g2))

      when "age", "-age", "~age" then add_to_query(type, :age, ParseValue.invert_range(ParseValue.range(g2, :age)))

      when "hot_from" then q[:hot_from] = ParseValue.date_from(g2)

      when "tagcount", "-tagcount", "~tagcount" then add_to_query(type, :post_tag_count, ParseValue.range(g2))

      when /[-~]?(#{TagCategory::SHORT_NAME_REGEX})tags/
        add_to_query(type, :"#{TagCategory::SHORT_NAME_MAPPING[$1]}_tag_count", ParseValue.range(g2))

      when "parent", "-parent", "~parent" then add_to_query(type, :parent_ids, g2, any_none_key: :parent) { g2.to_i }

      when "child" then q[:child] = g2.downcase

      when "randseed" then q[:random_seed] = g2.to_i

      when "order", "-order" then q[:order] = TagQuery.normalize_order_value(g2.downcase, invert: type == :must_not)

      when "limit"
        # Do nothing. The controller takes care of it.

      when "status"
        q[:status] = g2.downcase
        q[:status_must_not] = nil
        q[:show_deleted] ||= q[:status].in?(OVERRIDE_DELETED_FILTER_STATUS_VALUES)

      when "-status"
        q[:status_must_not] = g2.downcase
        q[:status] = nil
        q[:show_deleted] ||= q[:status_must_not].in?(OVERRIDE_DELETED_FILTER_STATUS_VALUES)

      when "filetype", "-filetype", "~filetype", "type", "-type", "~type" then add_to_query(type, :filetype, g2.downcase)

      when "description", "-description", "~description" then add_to_query(type, :description, g2)

      when "note", "-note", "~note" then add_to_query(type, :note, g2)

      when "delreason", "-delreason", "~delreason"
        q[:status] ||= "any" unless q[:status_must_not]
        q[:show_deleted] ||= true
        add_to_query(type, :delreason, g2, wildcard: true)

      when "deletedby", "-deletedby", "~deletedby"
        q[:status] ||= "any" unless q[:status_must_not]
        q[:show_deleted] ||= true
        add_to_query(type, :deleter, user_id_or_invalid(g2))

      when "upvote", "-upvote", "~upvote", "votedup", "-votedup", "~votedup"
        add_to_query(type, :upvote, privileged_user_id_or_invalid(g2))

      when "downvote", "-downvote", "~downvote", "voteddown", "-voteddown", "~voteddown"
        add_to_query(type, :downvote, privileged_user_id_or_invalid(g2))

      when "voted", "-voted", "~voted" then add_to_query(type, :voted, privileged_user_id_or_invalid(g2))

      when *COUNT_METATAGS then q[metatag_name.downcase.to_sym] = ParseValue.range(g2)

      when *BOOLEAN_METATAGS then q[metatag_name.downcase.to_sym] = parse_boolean(g2)

      else
        add_tag(token)
      end
    end

    normalize_tags if resolve_aliases
  end

  # Checks if a standard tag contains any of the following invalid characters:
  # * `-`
  # * `~`
  # * `\\`
  # * `,`
  # * `#`
  # * `$`
  # * `%`
  # * TODO: Non-printable characters [:graph:]
  #
  # Allows `*` for wildcard matching.
  #
  # Follows rules in `../logical/tag_name_validator.rb`.
  REGEX_VALID_TAG_CHECK = /[\,\#\$\%\\]/

  # Same as `TagQuery::REGEX_VALID_TAG_CHECK`, but disallows `*`
  REGEX_VALID_TAG_CHECK_2 = /[\*\,\#\$\%\\]/

  # Adds the tag to the query object based on its prefix and if it contains a wildcard.
  # ### Notes:
  # * Exits if it's not a facially valid tag. Stops prior behavior of searching for tags comprised
  # entirely of invalid characters (which would always be false but, if preceded by `~` or `-`,
  # wouldn't end the search).
  def add_tag(tag)
    if tag.start_with?("-")
      tag = tag[1..]
      if SETTINGS[:CHECK_TAG_VALIDITY] && REGEX_VALID_TAG_CHECK.match?(tag)
        return if !SETTINGS[:ERROR_ON_INVALID_TAG] || SETTINGS[:CATCH_INVALID_TAG]
        raise InvalidTagError.new(tag: tag, prefix: "-", query_obj: self)
      end
      if tag.include?("*")
        q[:tags][:must_not] += pull_wildcard_tags(tag.downcase)
      else
        q[:tags][:must_not] << tag.downcase
      end
    elsif tag.start_with?("~")
      tag = tag[1..]
      if SETTINGS[:CHECK_TAG_VALIDITY] && REGEX_VALID_TAG_CHECK_2.match?(tag)
        return if !SETTINGS[:ERROR_ON_INVALID_TAG] || SETTINGS[:CATCH_INVALID_TAG]
        raise InvalidTagError.new(tag: tag, prefix: "~", has_wildcard: tag.include?("*"), query_obj: self)
      end
      q[:tags][:should] << tag.downcase
    else
      if SETTINGS[:CHECK_TAG_VALIDITY] && REGEX_VALID_TAG_CHECK.match?(tag)
        return if !SETTINGS[:ERROR_ON_INVALID_TAG] || SETTINGS[:CATCH_INVALID_TAG]
        raise InvalidTagError.new(tag: tag, query_obj: self)
      end
      if tag.include?("*")
        q[:tags][:should] += pull_wildcard_tags(tag)
      else
        q[:tags][:must] << tag.downcase
      end
    end
  end

  # Add the specified metatag to the query object.
  #
  # ### Parameters
  # * `type`
  # * `key`
  # * `value` [`nil`]: The value to assign. Is overwritten by the output of the block (if given)
  # unless `any_none_key` is truthy & `value` is `none` or `any`, case insensitive.
  # * `any_none_key` [`nil`]:
  # * `wildcard` [`false`]:
  # #### Block
  # Returns the value of the metatag.
  def add_to_query(type, key, value = nil, any_none_key: nil, wildcard: false, &)
    if any_none_key && (value.downcase == "none" || value.downcase == "any")
      add_any_none_to_query(type, value.downcase, any_none_key)
      return
    end

    value = yield if block_given?
    value = value.squeeze("*") if wildcard # Collapse runs of wildcards for efficiency

    key = case type
          when :must then key
          when :must_not then :"#{key}_must_not"
          when :should then :"#{key}_should"
          else
            return
          end
    q[key] ||= []
    q[key] << value
  end

  def add_any_none_to_query(type, value, key)
    case type
    when :must then q[key] = value
    when :must_not then q[key] = value == "none" ? "any" : "none"
    when :should then q[:"#{key}_should"] = value
    end
  end

  def pull_wildcard_tags(tag)
    Tag.name_matches(tag)
       .limit(Danbooru.config.tag_query_limit) # .limit(tag_query_limit)
       .order("post_count DESC")
       .pluck(:name)
       .presence || ["~~not_found~~"]
  end

  def normalize_tags
    q[:tags][:must] = TagAlias.to_aliased(q[:tags][:must])
    q[:tags][:must_not] = TagAlias.to_aliased(q[:tags][:must_not])
    q[:tags][:should] = TagAlias.to_aliased(q[:tags][:should])
  end

  # Parses the string value of `TagQuery::BOOLEAN_METATAGS`, `ratinglocked`, `notelocked`, &
  # `statuslocked` to boolean `true` or `false`.
  # ### Parameters
  # * `value`
  # ### Returns
  # `true` if the (case-insensitive) value of `value` is `"true"`, `false` otherwise.
  #
  # OPTIMIZE: Benchmark `value&.casecmp("true") == 0`, `value&.downcase == "true"`, & `value&.casecmp("true").zero?`
  def parse_boolean(value)
    value&.downcase == "true"
  end

  def user_id_or_invalid(val)
    User.name_or_id_to_id(val).presence || -1
  end

  def privileged_user_id_or_invalid(val)
    if CurrentUser.is_moderator?
      User.name_or_id_to_id(val).presence
    elsif CurrentUser.is_member?
      CurrentUser.id.presence
    end || -1
  end
end
