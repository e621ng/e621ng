# frozen_string_literal: true

class TagQuery
  class CountExceededError < StandardError
    def initialize(msg = "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
      super(msg)
    end
  end

  class DepthExceededError < StandardError
    def initialize(msg = "You cannot have more than #{TagQuery::DEPTH_LIMIT} levels of grouping at a time")
      super(msg)
    end
  end

  COUNT_METATAGS = %w[
    comment_count
  ].freeze

  BOOLEAN_METATAGS = %w[
    hassource hasdescription isparent ischild inpool pending_replacements artverified
  ].freeze

  NEGATABLE_METATAGS = (%w[
    id filetype type rating description parent user user_id approver flagger deletedby delreason
    source status pool set fav favoritedby note locked upvote votedup downvote voteddown voted
    width height mpixels ratio filesize duration score favcount date age change tagcount
    commenter comm noter noteupdater
  ] + TagCategory::SHORT_NAME_LIST.map { |tag_name| "#{tag_name}tags" }).freeze

  # OPTIMIZE: Check what's best
  # Should avoid additional array allocations
  METATAGS = %w[md5 order limit child randseed ratinglocked notelocked statuslocked].concat(
    NEGATABLE_METATAGS, COUNT_METATAGS, BOOLEAN_METATAGS
  ).freeze
  # Should guarentee at most 1 resize
  # METATAGS = %w[md5 order limit child randseed ratinglocked notelocked statuslocked].push(
  #   *NEGATABLE_METATAGS, *COUNT_METATAGS, *BOOLEAN_METATAGS
  # ).freeze
  # Original
  # METATAGS = (%w[
  #   md5 order limit child randseed ratinglocked notelocked statuslocked
  # ] + NEGATABLE_METATAGS + COUNT_METATAGS + BOOLEAN_METATAGS).freeze

  ORDER_METATAGS = (%w[
    id id_desc
    score score_asc
    favcount favcount_asc
    created_at created_at_asc
    updated updated_desc updated_asc
    comment comment_asc
    comment_bumped comment_bumped_asc
    note note_asc
    mpixels mpixels_asc
    portrait landscape
    filesize filesize_asc
    tagcount tagcount_asc
    change change_desc change_asc
    duration duration_desc duration_asc
    rank
    random
  ] + COUNT_METATAGS + TagCategory::SHORT_NAME_LIST.flat_map { |str| ["#{str}tags", "#{str}tags_asc"] }).freeze

  # Only these tags hold global meaning and don't have added meaning by being in a grouped context.
  # Therefore, these should be pulled out of groups and placed on the top level of searches.
  GLOBAL_METATAGS = %w[order limit randseed].freeze

  # The values for the `status` metatag that will override the automatic hiding of deleted posts
  # from search results. Other tags do also alter this behavior; specifically, a `deletedby` or
  # `delreason` metatag.
  OVERRIDE_DELETED_FILTER_STATUS_VALUES = %w[deleted active any all].freeze

  # The metatags that can override the automatic hiding of deleted posts from search results. Note
  # that the `status` metatag alone ***does not*** override filtering; it must also have a value
  # present in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES`.
  OVERRIDE_DELETED_FILTER_METATAGS = %w[
    status -status
    delreason -delreason ~delreason
    deletedby -deletedby ~deletedby
  ].freeze

  delegate :[], :include?, to: :@q
  attr_reader :q, :resolve_aliases, :tag_count

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

    parse_query(query, **)
    raise CountExceededError if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
  end

  def is_grouped_search?
    q[:groups].present? && (q[:groups][:must].present? || q[:groups][:must_not].present? || q[:groups][:should].present?)
  end

  # Whether the default behavior to hide deleted posts should be overridden.
  #
  # * `always_show_deleted` [`false`]: The override value. Corresponds to
  # `ElasticPostQueryBuilder.always_show_deleted`.
  # * `at_any_level` [`false`]: Should groups be accounted for, or just this level?
  #
  # Returns true unless
  # * `always_show_deleted`,
  # * `q[:status]`/`q[:status_must_not]` contains a value in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES`,
  # * One of the following is non-nil:
  #   * `q[:deleter]`/`q[:deleter_must_not]`/`q[:deleter_should]`
  #   * `q[:delreason]`/`q[:delreason_must_not]`/`q[:delreason_should]`, or
  # * If `at_any_level`,
  #   * `q[:children_show_deleted]` is `true` or
  #   * any of the subsearches in `q[:groups]` return false from
  # `TagQuery.should_hide_deleted_posts?`
  #     * This is overriden to return `true` if the subsearches in `q[:groups]` are type `TagQuery`,
  # as preprocessed queries should have had their resultant value elevated to this level during
  # `process_groups`.
  def hide_deleted_posts?(always_show_deleted: false, at_any_level: false)
    if always_show_deleted || q[:show_deleted]
      false
    elsif at_any_level
      if q[:children_show_deleted].nil? &&
         q[:groups].present? &&
         [*(q[:groups][:must] || []), *(q[:groups][:must_not] || []), *(q[:groups][:should] || [])].any? { |e| e.is_a?(TagQuery) ? (raise "q[:children_show_deleted] shouldn't be nil.") : !TagQuery.should_hide_deleted_posts?(e, at_any_level: true) }
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
  # * `query` {String|String[]}:
  # * `always_show_deleted` [`false`]: The override value. Corresponds to
  # `ElasticPostQueryBuilder.always_show_deleted`.
  # * `at_any_level` [`true`]: Should values inside groups be accounted for?
  #
  # Returns false if `always_show_deleted` or `query` contains either a `delreason`/`deletedby`
  # metatgs or a `status` metatag w/ a value in `TagQuery::OVERRIDE_DELETED_FILTER_STATUS_VALUES` at
  # the specified depth; true otherwise.
  def self.should_hide_deleted_posts?(query, always_show_deleted: false, at_any_level: true)
    return false if always_show_deleted
    return query.hide_deleted_posts?(at_any_level: at_any_level) if query.is_a?(TagQuery)
    TagQuery.fetch_metatags(query, *OVERRIDE_DELETED_FILTER_METATAGS, prepend_prefix: false, at_any_level: at_any_level) do |tag, val|
      return false unless tag.end_with?("status") && !val.in?(OVERRIDE_DELETED_FILTER_STATUS_VALUES)
    end
    true
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
  TOKENIZE_REGEX = /\G(?>\s*)(?<token> # Match any leading whitespace to help with \G
  (?<prefix>[-~])?
  (?<body>
    (?<metatag>(?>\w*:(?>"[^\"]*"(?=\s|\z)|\S*)))| # Match a metatag (quoted or not)
    (?<group>(?> # Match a single group atomically by:
      (?>\(\s+) # 1. atomically matching a `(` & at least 1 whitespace character
      (?<subquery>(?> # Greedily find one of the following 2 options
        (?!(?<=\s)\)|(?>\s+)\)) # 2. Skip this option if a `)` that's preceeded by whitespace is next
        (?> # 3. Matching one of the following 3 options once:
          [-~]?\g<metatag>| # 3A. a metatag (to avoid misinterperting quoted input as groups)
          [-~]?\g<group>| # 3B. a group (to balence parentheses)
          (?> # 3C. Atomically match either
            [^\s)]+| # 1 or more non-whitespace, non-`)` characters greedily, or
            (?<!\s)\)+ # If not preceeded by whitespace, 1 or more `)`
          )* # 0 or more times greedily
        )
        (?>(?>\s+)(?!\)))?| # 4. Atomically match all contiguous whitespace (if present). Or;
        (?=(?<=\s)\)|(?>\s+)\)) # 5. Succeed if the prior char was whitespace and the next is a closing parenthesis. Backtracks the parenthesis. Takes advantage of special handling of zero-length matches.
      )+) # If step 5 succeeds, the zero-length match will force the engine to stop trying to match this group.
      (?>\s*)(?<=\s)\) # Check if preceeded by whitespace and match the closing parenthesis.
    )(?=\s|\z))|
    (?<tag>\S+) # Match non-whitespace characters (tags)
  ))(?>\s*)/x # Match any trailing whitespace to help with \G

  # A group existence checker
  #
  # Doesn't exclude group opener whose only potential group terminators are in quoted metatags.
  HAS_GROUP_REGEX = /\A(?>\s*)(?<main>(?<group>(?>[-~]?\(\s+(?>[^\s)]+|(?<!\s)\)+|\s+)*(?<=\s)\)))|(?>\s*[-~]?(?>\w*:"[^"]*"|[^\s\(]+|\(+(?!\s))\s*)+\g<main>)/
  # Only allows empty group w/ >1 space
  # HAS_GROUP_REGEX = /\A(?>\s*)(?<main>(?<group>(?>[-~]?\(\s+(?>[^\s)]+|(?<!\s)\)+|\s+(?!\)))*\s\)))|(?>\s*[-~]?(?>\w*:"[^"]*"|[^\s\(]+|\(+(?!\s))\s*)+\g<main>)/

  # A group existence checker that excludes empty groups
  #
  # Doesn't exclude group opener whose only potential group terminators are in quoted metatags.
  HAS_NON_EMPTY_GROUP_REGEX = /\A(?>\s*)(?<main>(?<group>(?>[-~]?\(\s+(?>[^\s)]+|(?<!\s)\)+|\s+(?!\)))+\s\)))|(?>\s*[-~]?(?>\w*:"[^"]*"|[^\s\(]+|\(+(?!\s))\s*)+\g<main>)/

  # A simple group existence checker; doesn't account for groups inside of/immediately following (w/
  # no whitespace) quoted metatags.
  SIMPLE_GROUP_REGEX = /(?>(\A|\s)[-~]?\(\s+)(?>[^\s)]+|(?<!\s)\)+|\s+(?!\)))+\s\)/
  # SIMPLE_GROUP_REGEX = /(?>(\A|\s)[-~]?\(\s+).+\s\)/

  # METATAG_REGEX = /(?>\G|\A|\s+)(?<prefix>[-~]?)(?<metatag>(?>(?<name>\w*):(?<value>(?>"[^"]*"|\S*))))/

  # OPTIMIZE: Profile variants
  def self.has_groups?(tag_str, exclude_empty: false)
    return tag_str.is_grouped_search? if tag_str.is_a?(TagQuery)
    # What's fastest:
    # * removing quoted metatags and
    #   * immediately using a simple regex?
    #   * checking for opening & closing parentheses then using a simple regex?
    # * Iterating through tags until a group is found?
    # Option 1: Removing quoted metatags immediately
    # Checking for opening & closing parentheses
    return false unless tag_str.presence&.match(exclude_empty ? /\(\s+(?>[^\s)]+|(?<!\s)\)+|\s+(?!\)))+\s\)/ : /\(\s+(?>[^\s)]+|(?<!\s)\)+|\s+)*(?<=\s)\)/)
    # tag_str = tag_str.gsub(/\s*[-~]?\w*?:".+?"/, "")
    # tag_str = tag_str.gsub(/\s*[-~]?\w*?:".*?"/, "")
    # tag_str = tag_str.gsub(/\s*[-~]?\w*?:"[^"]+"/, "")
    # tag_str = tag_str.gsub(/\s*[-~]?\w*?:"[^"]*"/, "")
    tag_str = tag_str.gsub(/(?:\G|(?<=\s))(?>[-~]?\w*?:"[^"]*)"/, "")
    # # Checking for opening & closing parentheses
    # return false unless tag_str.presence&.include?("( ") && tag_str.include?(" )")
    # Using a simple regex
    SIMPLE_GROUP_REGEX.match?(tag_str)
  end

  # Iterates through tokens, returning each tokens' `MatchData` in accordance with
  # `TagQuery::TOKENIZE_REGEX`.
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

    if recurse
      tag_str.scan(TOKENIZE_REGEX) do |_|
        m = Regexp.last_match
        results << (block_given? ? yield(m) : m) if m[:group] || stop_at_group
        if (m = m[:group]&.match(/\A\((?>\s+)(.+)(?<=\s)\)\z/)&.match(1)&.rstrip)
          results.push(*TagQuery.match_tokens(m, **kwargs, recurse: recurse, stop_at_group: stop_at_group, depth: depth + 1, &))
        end
      end
    else
      tag_str.scan(TOKENIZE_REGEX) do |_|
        unless !stop_at_group && Regexp.last_match[:group]
          results << (block_given? ? yield(Regexp.last_match) : Regexp.last_match)
        end
      end
    end
    results
  end

  # Scan variant that properly handles groups.
  #
  # * `query`
  # * `hoisted_metatags` [`TagQuery::GLOBAL_METATAGS`]: the metatags to lift out of groups to the
  # top level.
  # * `error_on_depth_exceeded` [`false`]
  # * `filter_empty_groups` [`true`]
  # * `max_tokens_to_process` [`Danbooru.config.tag_query_limit * 2`]
  def self.scan_search(
    query,
    hoisted_metatags: TagQuery::GLOBAL_METATAGS,
    error_on_depth_exceeded: false,
    **kwargs
  )
    depth_limit = TagQuery::DEPTH_LIMIT unless (depth_limit = kwargs.fetch(:depth_limit, nil)).is_a?(Numeric) && depth_limit <= TagQuery::DEPTH_LIMIT
    depth = 0 unless (depth = kwargs.fetch(:depth, nil)).is_a?(Numeric) && depth >= 0
    return (error_on_depth_exceeded ? (raise DepthExceededError) : []) if depth_limit <= depth
    tag_str = query.to_s.unicode_normalize(:nfc).strip
    # Quick exit if given a blank search or a single group w/ an empty search
    return [] if tag_str.blank? || /\A[-~]?\(\s+\)\z/.match?(tag_str)
    # Quick and dirty optimization: If it can't contain any groups, use a simpler tokenizer.
    return TagQuery.scan(tag_str) unless HAS_GROUP_REGEX.match?(tag_str)
    # If this query is composed of 1 top-level group with no modifiers, convert to ungrouped.
    # TODO: Check if regex catches nested groups & quoted metatag groups
    if SETTINGS[:EARLY_SCAN_SEARCH_CHECK] && (top = tag_str[/\A(?>\(\s+)((?>[^\s)]+|(?<!\s)\)+|(?>\s+)(?!\)))+)\s+\)\z/, 1]).present?
      return scan_search(
        top.rstrip,
        **kwargs,
        hoisted_metatags: hoisted_metatags,
        depth_limit: depth_limit -= 1,
        error_on_depth_exceeded: error_on_depth_exceeded,
      )
    end
    matches = []
    scan_opts = { recurse: false, stop_at_group: true, error_on_depth_exceeded: error_on_depth_exceeded }.freeze
    # TODO: Check if uniq is too slow as is
    # If so, try using a set to check if included, or using the uniq method.
    # iterations = -1
    TagQuery.match_tokens(tag_str, **scan_opts) do |m|
      # iterations += 1
      # If it's not a group, move on with this value.
      if m[:group].blank?
        matches << m[:token] unless matches.include?(m[:token])
        next
      end
      # If it's an empty group and we filter those, skip this value.
      next if kwargs.fetch(:filter_empty_groups, true) && m[:subquery].blank?
      # This will change the tag order, putting the hoisted tags in front of the groups that previously contained them
      if hoisted_metatags.present? && m[:subquery]&.match(/(?<=\A|\s)#{hoist_regex_stub ||= "(?>#{hoisted_metatags.join('|')})"}:\S+/)
        cb = ->(sub_match) do
          # if there's a group w/ a hoisted tag,
          if sub_match[:subquery]&.match?(/(?<=\A|\s)#{hoist_regex_stub}:\S*/)
            raise DepthExceededError if (depth + 1) >= depth_limit && error_on_depth_exceeded
            next kwargs.fetch(:filter_empty_groups, true) ? sub_match[:token] : nil if sub_match[:subquery].blank? # rubocop:disable Metrics/BlockNesting
            r_out = (depth += 1) >= depth_limit ? " " : "#{TagQuery.match_tokens(sub_match[:subquery], **scan_opts, depth: depth, &cb).compact.uniq.join(' ')} "
            depth -= 1
            next "#{sub_match[:prefix]}( #{r_out})"
          elsif (sub_match[:metatag].presence || "")[/\A#{hoist_regex_stub}:\S*/]
            matches << sub_match[:token]
            next nil
          end
          sub_match[:token]
        end
        next (out_v = cb.call(m)).is_a?(Array) ? matches.push(*out_v.compact.uniq) : matches << out_v
      end
      matches << m[0].strip
    end
    matches
  end

  # Doesn't account for grouping, but DOES preserve quoted metatag ordering
  #
  # OPTIMIZE: Profile variants (including scan_legacy)
  def self.scan(query, **)
    out = []
    query.to_s.unicode_normalize(:nfc).strip.presence
         &.scan(/\G(?>\s*)(?<prefix>[-~])?(?<body>(?<metatag>(?>\w*:(?>"[^"]*"|\S*)))|(?<tag>\S+))(?>\s*)/) { |_| out << "#{$1}#{$2}" }
    out.uniq
  end

  # Doesn't account for grouping, but DOES preserve quoted metatag ordering
  # def self.scan1(query)
  #   tag_str = query.to_s.unicode_normalize(:nfc).strip
  #   matches = []
  #   # while (m = tag_str.match(/[-~]?\w*?:".*?"/))
  #   while (m = tag_str.match(/[-~]?\w*?:"[^"]*"/))
  #     if m.begin(0) >= 0 then matches.push(*tag_str.slice!(0, m.end(0))[0, m.begin(0)].split) end
  #     matches << m[0]
  #     ""
  #   end
  #   matches.push(*tag_str.split) if tag_str.present?
  #   matches.uniq
  # end

  # Legacy scan variant (doesn't account for grouping, doesn't preserve quoted metatag ordering)
  def self.scan_legacy(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    quote_delimited = []
    tagstr = tagstr.gsub(/[-~]?\w*?:".*?"/) do |match|
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
  #
  # #### Recursive Parameters (SHOULDN'T BE USED BY OUTSIDE METHODS)
  # * `depth` [0]: Tracks recursive depth to prevent exceeding `TagQuery::DEPTH_LIMIT`
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
                      m[:body][/\A\(\s+\)\z/] ? "" : m[:body][/\A\(\s+(.*)\s+\)\z/, 1],
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
          m[0].strip,
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
  # * `metatags` { `String`s | :any }: The metatags to search for.
  # * `initial_value` [`nil`]: The starting value passed to block and returned if no matches are
  # found.
  # * `prepend_prefix` [`false`]: Match the tags w/ any prefix (e.g. `-status` instead of `status`)?
  # Defaults to only matching the explicitly specified prefix-metatag combinations.
  #
  # #### Block:
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
  def self.scan_metatags(query, *metatags, initial_value: nil, prepend_prefix: false, &)
    return initial_value if metatags.blank? || (query = query.to_s.unicode_normalize(:nfc).strip).blank?
    prefix = "([-~]?)" if prepend_prefix
    if [metatags].include?(:any)
      mts = "(?>\\w+)"
    else
      mts = metatags.inject(nil) { |p, e| (p ? "#{p}|#{e.to_s.strip}" : e.to_s.strip) if e.present? }
    end
    last_index = 0
    on_success = ->(curr_match) do
      if block_given?
        kwargs_hash = if prepend_prefix
                        { prefix: curr_match[1], tag: curr_match[2], value: curr_match[3] }
                      else
                        { tag: curr_match[1], value: curr_match[2] }
                      end
        initial_value = yield(
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
    # # For each quoted metatag, match all the non-quoted queried metatags between the end of the last
    # # quoted metatag and the start of this one, then check and process this quoted metatag.
    # # while (quoted_m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))(?>[-~]?\w*:"[^"]*"(?=\s|\z))/)) # This will cause rubocop to error https://github.com/rubocop/rubocop/releases/tag/v1.69.2 https://github.com/rubocop/rubocop/issues/13511
    # while (quoted_m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))(?:[-~]?\w*:"[^"]*"(?=\s|\z))/i))
    #   while (m = query[last_index...quoted_m.begin(0)].presence&.match(/(?:\A|(?<=\s))#{prefix}(#{mts}):"?(\S*)/i))
    #     on_success.call(m)
    #   end
    #   # Check if the quoted metatag matches the searched queries (also fixes match offsets for callback).
    #   if (m = query[last_index...quoted_m.end(0)].match(/(?:\A|(?<=\s))#{prefix}(#{mts}):"([^"]*)"/i))
    #     on_success.call(m)
    #   else # Manually update last_index since callback didn't do it.
    #     last_index = quoted_m.end(0)
    #   end
    # end
    # # This catches all metatags following the last quoted metatag, or all the metatags if there are
    # # no quoted metatags.
    # while (m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))#{prefix}(#{mts}):"?(\S*)/i))
    #   on_success.call(m)
    # end

    # For each quoted metatag, match all the non-quoted queried metatags between the end of the last
    # quoted metatag and the start of this one, then check and process this quoted metatag.
    #
    # If there's no (more) quoted metatags, then just search each metatag between the last index and the end.
    loop do
      # update rubocop https://github.com/rubocop/rubocop/releases/tag/v1.69.2 https://github.com/rubocop/rubocop/issues/13511
      # quoted_m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))(?>[-~]?\w*:"[^"]*"(?=\s|\z))/)
      quoted_m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))(?:[-~]?\w*:"[^"]*"(?=\s|\z))/i)
      while (m = query[last_index...(quoted_m&.begin(0) || query.length)].presence&.match(/(?:\A|(?<=\s))#{prefix}(#{mts}):"?(\S*)/i))
        on_success.call(m)
      end
      if quoted_m
        # Check if the quoted metatag matches the searched queries (also fixes match offsets for callback).
        if (m = query[last_index...quoted_m.end(0)].match(/(?:\A|(?<=\s))#{prefix}(#{mts}):"([^"]*)"/i))
          on_success.call(m)
        else # Manually update last_index since callback didn't do it.
          last_index = quoted_m.end(0)
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
  # * `tags`: The content to search through. Accepts strings and arrays.
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
        scan_metatags(tags, *metatags, prepend_prefix: prepend_prefix) { |**kwargs| return kwargs[:value] if kwargs[:value].present? }
        return
      else
        tags = scan(tags).find do |tag|
          metatag_name, value = tag.split(":", 2)
          if metatags.include?(metatag_name)
            value = value.delete_prefix('"').delete_suffix('"') if value.is_a?(String) # rubocop:disable Metrics/BlockNesting
            return value if value.present? # rubocop:disable Metrics/BlockNesting
          end
        end
      end
    elsif at_any_level
      # OPTIMIZE: See if checking and only sifting through grouped tags is substantively faster than sifting through all of them
      scan_metatags(tags.join(" "), *metatags, prepend_prefix: prepend_prefix) { |**kwargs| return kwargs[:value] if kwargs[:value].present? }
      return
    end
    return nil unless tags
    tags.find do |tag|
      metatag_name, value = tag.split(":", 2)
      if metatags.include?(metatag_name)
        value = value.delete_prefix('"').delete_suffix('"') if value.is_a?(String)
        return value if value.present?
      end
    end
  end

  def self.has_metatags?(tags, *metatags, at_any_level: true, prepend_prefix: false, has_all: true)
    r = fetch_metatags(tags, *metatags, prepend_prefix: prepend_prefix, at_any_level: at_any_level)
    r.present && metatags.send(has_all ? :all? : :any?) { |mt| r.key?(mt) }
  end

  # Pulls the values from the specified metatags.
  #
  # ### Parameters
  # * `tags`: The content to search through. Accepts strings and arrays.
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
        return scan_metatags(tags, *metatags, prepend_prefix: prepend_prefix) do |**kwargs|
          metatag_name = kwargs[:tag]
          value = kwargs[:value]
          next if value.blank?
          ret_val[metatag_name] ||= []
          ret_val[metatag_name] << (block_given? ? yield(metatag_name, value) : value)
        end
      else
        tags = scan(tags)
      end
    elsif at_any_level
      # OPTIMIZE: See if checking and only sifting through grouped tags is substantively faster than sifting through all of them
      return scan_metatags(tags.join(" "), *metatags, prepend_prefix: prepend_prefix) do |**kwargs|
        metatag_name = kwargs[:tag]
        value = kwargs[:value]
        next if value.blank?
        ret_val[metatag_name] ||= []
        ret_val[metatag_name] << (block_given? ? yield(metatag_name, value) : value)
      end
    end
    return {} unless tags.presence
    ret_val = {}
    tags.each do |tag|
      metatag_name, value = tag.split(":", 2)
      next unless metatags.include?(metatag_name)
      value = value.delete_prefix('"').delete_suffix('"') if value.is_a?(String)
      next if value.blank?
      ret_val[metatag_name] ||= []
      ret_val[metatag_name] << (block_given? ? yield(metatag_name, value) : value)
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
        if temp.match(/\A[-~]?\(\s.*\s\)\z/)
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

  def self.ad_tag_string(tag_array)
    if (i = tag_array.index { |v| v == "(" }) && i < (tag_array.index { |v| v == ")" } || -1)
      tag_array = TagQuery.scan_recursive(
        tag_array.join(" "),
        strip_duplicates_at_level: false,
        delimit_groups: false,
        flatten: true,
        strip_prefixes: false,
        sort_at_level: false,
        # NOTE: It would seem to be wise to normalize these tags
        normalize_at_level: false,
      )
    end
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

  # Used for quickly profiling optimizations, tweaking desired behavior, etc.
  # * `COUNT_TAGS_WITH_SCAN_RECURSIVE`: Use `TagQuery.scan_recursive` to increment `@tag_count` in
  # `parse_query`?
  # * `STOP_ON_TAG_COUNT_EXCEEDED`: Short-circuit immediately when max tags exceeded?
  # * `EARLY_SCAN_SEARCH_CHECK`: Check for a top level query before using the more expensive
  # tokenizer?
  #   * Better if query contains no closing parenthesis aside from the group delimiter, worse
  # otherwise.
  # * `CHECK_GROUP_TAGS_AND_DEPTH`: Count tags in group & group depth at each step, or allow these
  # checks to occur as groups are recursively processed?
  #   * true: always check
  #   * false: always count as part of the recursive process
  #   * anything else: count at the root
  SETTINGS = {
    COUNT_TAGS_WITH_SCAN_RECURSIVE: false,
    STOP_ON_TAG_COUNT_EXCEEDED: true,
    EARLY_SCAN_SEARCH_CHECK: true,
    CHECK_GROUP_TAGS_AND_DEPTH: true,
  }.freeze

  def pq_check_group_tags?(depth)
    SETTINGS[:CHECK_GROUP_TAGS_AND_DEPTH] == true || (SETTINGS[:CHECK_GROUP_TAGS_AND_DEPTH] != false && depth <= 0)
  end

  def pq_count_tags(group, depth, tag_query_limit)
    if SETTINGS[:COUNT_TAGS_WITH_SCAN_RECURSIVE]
      TagQuery.scan_recursive(
        group,
        flatten: true, delimit_groups: false, strip_prefixes: true, depth: depth + 1,
        strip_duplicates_at_level: false, error_on_depth_exceeded: true
      ).count { |token| Danbooru.config.is_unlimited_tag?(token) }
    else
      delta = 0
      TagQuery.match_tokens(
        group,
        recurse: true,
        stop_at_group: false,
        error_on_depth_exceeded: true,
        depth: depth + 1,
      ) do |token|
        next if Danbooru.config.is_unlimited_tag?(token[0].strip)
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
  # * Quoted metatags aren't distinguished from non-quoted metatags nor standard tags in `TagQuery.parse_query`; to ensure consistency, even malformed metatags must have leading and trailing double quotes removed.
  def parse_query(query, depth: 0, **kwargs)
    tag_query_limit = Danbooru.config.tag_query_limit - @free_tags_count if SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED] && (kwargs[:process_groups] || pq_check_group_tags?(depth))
    can_have_groups = kwargs.fetch(:can_have_groups, true) && TagQuery.has_groups?(query.to_s.unicode_normalize(:nfc))
    if can_have_groups # rubocop:disable Metrics/BlockLength
      TagQuery.scan_search(query, **kwargs, depth: depth)
    else
      TagQuery.scan(query)
    end.each do |token|
      # If there's a non-empty group, correctly increment tag_count, then stop processing/recursively process this token.
      if can_have_groups && (match = /\A([-~]?)\(\s+(.+)(?<!\s)\s+\)\z/.match(token))
        group = match[2]
        @tag_count += if kwargs[:process_groups]
                        (group = TagQuery.new(
                          group,
                          free_tags_count: @tag_count + @free_tags_count,
                          resolve_aliases: @resolve_aliases, return_with_count_exceeded: true,
                          hoisted_metatags: nil, depth: depth + 1
                        )).tag_count
                      elsif pq_check_group_tags?(depth)
                        pq_count_tags(group, depth, tag_query_limit)
                      else
                        0
                      end
        raise CountExceededError if SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED] && @tag_count > tag_query_limit
        next if group.blank?
        q[:children_show_deleted] = group.hide_deleted_posts?(at_any_level: true) if kwargs[:process_groups]
        # TODO: Convert to style in `add_to_query` (:groups_must, :groups_must_not, etc.) to better reuse pre-existing logic
        search_type = METATAG_SEARCH_TYPE[match[1]]
        q[:groups] ||= {}
        q[:groups][search_type] ||= []
        q[:groups][search_type] << group
        next
      end
      unless Danbooru.config.is_unlimited_tag?(token)
        @tag_count += 1
        raise CountExceededError if SETTINGS[:STOP_ON_TAG_COUNT_EXCEEDED] && @tag_count > tag_query_limit
      end
      metatag_name, g2 = token.split(":", 2)

      # Short-circuit when there is no metatag or the metatag has no value
      if g2.blank? || !/\A(?>[-~]?\w*)\z/.match?(metatag_name)
        add_tag(token)
        next
      end

      # Remove quotes from description:"abc def"
      g2 = g2.delete_prefix('"').delete_suffix('"')

      # The following prevents empty/whitespace-only values after quote removal; the above allows
      # # Short-circuit when the metatag name has invalid characters in it, there is no metatag, or
      # # the metatag has no value. Remove quotes from description:"abc def".
      # if !/\A(?>[-~]?\w*)\z/.match?(metatag_name) ||
      #    (g2 = g2.presence&.delete_prefix('"')&.delete_suffix('"')).blank?
      #   add_tag(token)
      #   next
      # end

      type = METATAG_SEARCH_TYPE[metatag_name[0]]
      case metatag_name.downcase
      when "user", "-user", "~user"
        add_to_query(type, :uploader_ids) { user_id_or_invalid(g2) }

      when "user_id", "-user_id", "~user_id"
        add_to_query(type, :uploader_ids) { g2.to_i }

      when "approver", "-approver", "~approver"
        add_to_query(type, :approver_ids, any_none_key: :approver, value: g2) { user_id_or_invalid(g2) }

      when "commenter", "-commenter", "~commenter", "comm", "-comm", "~comm"
        add_to_query(type, :commenter_ids, any_none_key: :commenter, value: g2) { user_id_or_invalid(g2) }

      when "noter", "-noter", "~noter"
        add_to_query(type, :noter_ids, any_none_key: :noter, value: g2) { user_id_or_invalid(g2) }

      when "noteupdater", "-noteupdater", "~noteupdater"
        add_to_query(type, :note_updater_ids) { user_id_or_invalid(g2) }

      when "pool", "-pool", "~pool"
        add_to_query(type, :pool_ids, any_none_key: :pool, value: g2) { Pool.name_to_id(g2) }

      when "set", "-set", "~set"
        add_to_query(type, :set_ids) do
          post_set_id = PostSet.name_to_id(g2)
          post_set = PostSet.find_by(id: post_set_id)

          next 0 unless post_set
          raise User::PrivilegeError unless post_set.can_view?(CurrentUser.user)

          post_set_id
        end

      when "fav", "-fav", "~fav", "favoritedby", "-favoritedby", "~favoritedby"
        add_to_query(type, :fav_ids) do
          favuser = User.find_by_name_or_id(g2) # rubocop:disable Rails/DynamicFindBy

          next 0 unless favuser
          raise Favorite::HiddenError if favuser.hide_favorites?

          favuser.id
        end

      when "md5"
        q[:md5] = g2.downcase.split(",")[0..99]

      when "rating", "-rating", "~rating"
        add_to_query(type, :rating) { g2[0]&.downcase || "miss" }

      when "locked", "-locked", "~locked"
        add_to_query(type, :locked) do
          case g2.downcase
          when "rating"
            :rating
          when "note", "notes"
            :note
          when "status"
            :status
          end
        end

      when "ratinglocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :rating }
      when "notelocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :note }
      when "statuslocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :status }

      when "id", "-id", "~id"
        add_to_query(type, :post_id) { ParseValue.range(g2) }

      when "width", "-width", "~width"
        add_to_query(type, :width) { ParseValue.range(g2) }

      when "height", "-height", "~height"
        add_to_query(type, :height) { ParseValue.range(g2) }

      when "mpixels", "-mpixels", "~mpixels"
        add_to_query(type, :mpixels) { ParseValue.range_fudged(g2, :float) }

      when "ratio", "-ratio", "~ratio"
        add_to_query(type, :ratio) { ParseValue.range(g2, :ratio) }

      when "duration", "-duration", "~duration"
        add_to_query(type, :duration) { ParseValue.range(g2, :float) }

      when "score", "-score", "~score"
        add_to_query(type, :score) { ParseValue.range(g2) }

      when "favcount", "-favcount", "~favcount"
        add_to_query(type, :fav_count) { ParseValue.range(g2) }

      when "filesize", "-filesize", "~filesize"
        add_to_query(type, :filesize) { ParseValue.range_fudged(g2, :filesize) }

      when "change", "-change", "~change"
        add_to_query(type, :change_seq) { ParseValue.range(g2) }

      when "source", "-source", "~source"
        add_to_query(type, :sources, any_none_key: :source, value: g2, wildcard: true) { "#{g2}*" }

      when "date", "-date", "~date"
        add_to_query(type, :date) { ParseValue.date_range(g2) }

      when "age", "-age", "~age"
        add_to_query(type, :age) { ParseValue.invert_range(ParseValue.range(g2, :age)) }

      when "tagcount", "-tagcount", "~tagcount"
        add_to_query(type, :post_tag_count) { ParseValue.range(g2) }

      when /[-~]?(#{TagCategory::SHORT_NAME_REGEX})tags/
        add_to_query(type, :"#{TagCategory::SHORT_NAME_MAPPING[$1]}_tag_count") { ParseValue.range(g2) }

      when "parent", "-parent", "~parent"
        add_to_query(type, :parent_ids, any_none_key: :parent, value: g2) { g2.to_i }

      when "child"
        q[:child] = g2.downcase

      when "randseed"
        q[:random_seed] = g2.to_i

      when "order"
        q[:order] = g2.downcase

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

      when "filetype", "-filetype", "~filetype", "type", "-type", "~type"
        add_to_query(type, :filetype) { g2.downcase }

      when "description", "-description", "~description"
        add_to_query(type, :description) { g2 }

      when "note", "-note", "~note"
        add_to_query(type, :note) { g2 }

      when "delreason", "-delreason", "~delreason"
        q[:status] ||= "any" unless q[:status_must_not]
        q[:show_deleted] ||= true
        add_to_query(type, :delreason, wildcard: true) { g2 }

      when "deletedby", "-deletedby", "~deletedby"
        q[:status] ||= "any" unless q[:status_must_not]
        q[:show_deleted] ||= true
        add_to_query(type, :deleter) { user_id_or_invalid(g2) }

      when "upvote", "-upvote", "~upvote", "votedup", "-votedup", "~votedup"
        add_to_query(type, :upvote) { conditional_user_id_or_invalid(g2) }

      when "downvote", "-downvote", "~downvote", "voteddown", "-voteddown", "~voteddown"
        add_to_query(type, :downvote) { conditional_user_id_or_invalid(g2) }

      when "voted", "-voted", "~voted"
        add_to_query(type, :voted) { conditional_user_id_or_invalid(g2) }

      when *COUNT_METATAGS
        q[metatag_name.downcase.to_sym] = ParseValue.range(g2)

      when *BOOLEAN_METATAGS
        q[metatag_name.downcase.to_sym] = parse_boolean(g2)

      else
        add_tag(token)
      end
    end

    normalize_tags if resolve_aliases
  end

  def add_tag(tag)
    # If it's a single character modifier, add it and exit.
    if ["-", "~"].include?(tag)
      q[:tags][:must] << tag
      return
    end
    tag = tag.downcase
    case tag[0]
    when "-"
      if tag.include?("*")
        q[:tags][:must_not] += pull_wildcard_tags(tag.delete_prefix("-"))
      else
        q[:tags][:must_not] << tag.delete_prefix("-")
      end
      return
    when "~"
      q[:tags][:should] << tag.delete_prefix("~")
      return
    end
    if tag.include?("*")
      q[:tags][:should] += pull_wildcard_tags(tag)
    else
      q[:tags][:must] << tag
    end
  end

  def add_to_query(type, key, any_none_key: nil, value: nil, wildcard: false, &)
    if any_none_key && (value.downcase == "none" || value.downcase == "any")
      add_any_none_to_query(type, value.downcase, any_none_key)
      return
    end

    value = yield
    value = value.squeeze("*") if wildcard # Collapse runs of wildcards for efficiency

    case type
    when :must
      q[key] ||= []
      q[key] << value
    when :must_not
      q[:"#{key}_must_not"] ||= []
      q[:"#{key}_must_not"] << value
    when :should
      q[:"#{key}_should"] ||= []
      q[:"#{key}_should"] << value
    end
  end

  def add_any_none_to_query(type, value, key)
    case type
    when :must
      q[key] = value
    when :must_not
      if value == "none"
        q[key] = "any"
      else
        q[key] = "none"
      end
    when :should
      q[:"#{key}_should"] = value
    end
  end

  def pull_wildcard_tags(tag)
    matches = Tag.name_matches(tag).limit(Danbooru.config.tag_query_limit).order("post_count DESC").pluck(:name)
    matches = ["~~not_found~~"] if matches.empty?
    matches
  end

  def normalize_tags
    q[:tags][:must] = TagAlias.to_aliased(q[:tags][:must])
    q[:tags][:must_not] = TagAlias.to_aliased(q[:tags][:must_not])
    q[:tags][:should] = TagAlias.to_aliased(q[:tags][:should])
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def user_id_or_invalid(val)
    User.name_or_id_to_id(val).presence || -1
  end

  def conditional_user_id_or_invalid(val)
    if CurrentUser.is_moderator?
      User.name_or_id_to_id(val).presence
    elsif CurrentUser.is_member?
      CurrentUser.id.presence
    end || -1
  end
end
