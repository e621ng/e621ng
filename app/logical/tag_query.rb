# frozen_string_literal: true

class TagQuery
  class CountExceededError < StandardError
    def initialize(msg = "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
      super(msg)
    end
  end

  class CountExceededWithDataError < CountExceededError
    delegate :[], :include?, to: :@q
    attr_reader :q, :resolve_aliases, :tag_count

    def initialize(
      msg = "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time",
      query_obj:,
      resolve_aliases:,
      tag_count:
    )
      @q = query_obj
      @resolve_aliases = resolve_aliases
      @tag_count = tag_count
      super(msg)
    end
  end

  class DepthExceededError < StandardError
    def initialize(msg = "You cannot have more than #{TagQuery::DEPTH_LIMIT} levels of grouping at a time")
      super(msg)
    end
  end

  class DepthExceededWithDataError < DepthExceededError
    delegate :[], :include?, to: :@q
    attr_reader :q, :resolve_aliases, :tag_count

    def initialize(
      msg = "You cannot have more than #{TagQuery::DEPTH_LIMIT} levels of grouping at a time",
      query_obj:,
      resolve_aliases:,
      tag_count:
    )
      @q = query_obj
      @resolve_aliases = resolve_aliases
      @tag_count = tag_count
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

  METATAGS = (%w[
    md5 order limit child randseed ratinglocked notelocked statuslocked
  ] + NEGATABLE_METATAGS + COUNT_METATAGS + BOOLEAN_METATAGS).freeze

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

  ##
  # Only these tags hold global meaning and don't have added meaning by being in a grouped context.
  # Therefore, these should be pulled out of groups
  GLOBAL_METATAGS = %w[
    order limit randseed
  ].freeze

  ##
  # The valid values for the status metatag.
  # any == all, modqueue == (pending || flagged), active == (!pending && !flagged && !deleted)
  STATUS_VALUES = %w[
    all any pending flagged modqueue deleted active
  ].freeze

  delegate :[], :include?, to: :@q
  attr_reader :q, :resolve_aliases, :tag_count

  ##
  # `query`:
  # resolve_aliases: Defaults to `true`.
  # free_tags_count: Defaults to `0`.
  # return_with_count_exceeded: Defaults to `false`.
  # process_groups: Defaults to `false`.
  # error_on_depth_exceeded: Defaults to `true`.
  # depth: defaults to `1`
  def initialize(
    query,
    resolve_aliases: true,
    free_tags_count: 0,
    return_with_count_exceeded: false,
    **
  )
    @q = {
      tags: {
        must: [],
        must_not: [],
        should: [],
      },
      groups: {
        must: [],
        must_not: [],
        should: [],
      },
    }
    @resolve_aliases = resolve_aliases
    @tag_count = 0
    @free_tags_count = free_tags_count

    parse_query(query, **)
    if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
      if return_with_count_exceeded
        raise CountExceededWithDataError.new(query_obj: @q, resolve_aliases: @resolve_aliases, tag_count: @tag_count)
      else
        raise CountExceededError, "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time"
      end
    end
  end

  ##
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

  ##
  # Convert query into a consistent representation while honoring grouping.
  # Recursively:
  # * Converts to string
  # * Unicode normalizes w/ nfc
  # * Removes leading & trailing whitespace
  # * For each token:
  #   * Converts to lowercase
  #   * Removes leading & trailing whitespace
  #   * Converts interior whitespace to underscores
  #   * Resolves tag aliases
  # * Sorts
  # * Removes duplicates at that group's top level
  # Then, if `flatten`, Joins into a unified string
  def self.normalize_search(query, flatten: true)
    tags = scan_recursive(
      query,
      flatten: flatten,
      strip_duplicates_at_level: true,
      strip_prefixes: false,
      sort_at_level: true,
      normalize_at_level: true,
    )
    flatten ? tags.join(" ") : tags
  end

  def self.tokenize_regex
    # /\G(?<prefix>[-~])?(?<body>(?<metatag>(?>\w*:"[^"]*"))|(?<group>(?>(?>\(\s+)(?>(?!(?<=\s)\))(?>[-~]?\g<metatag>|[-~]?\g<group>|(?>[^\s)]+|(?<!\s)\))*)(?>\s*)|(?=(?<=\s)\)))+(?<=\s)\)))|(?<tag>\S+))(?>\s*)/
    /\G(?<prefix>[-~])?(?<body>(?<metatag>(?>\w*:(?>"[^"]*"|\S*)))|(?<group>(?>(?>\(\s+)(?>(?!(?<=\s)\))(?>[-~]?\g<metatag>|[-~]?\g<group>|(?>[^\s)]+|(?<!\s)\))*)(?>\s*)|(?=(?<=\s)\)))+(?<=\s)\)))|(?<tag>\S+))(?>\s*)/
  end

  def self.match_tokens(
    tagstr,
    recurse: false,
    stop_at_group: false,
    and_then: nil,
    &block
  )
    tagstr = tagstr.to_s.unicode_normalize(:nfc).strip
    r = []
    if recurse
      tagstr.scan(tokenize_regex) do |_|
        m = Regexp.last_match
        r << (block_given? ? block.call(m) : m) if m[:group].blank? || stop_at_group
        if m[:group].present?
          r << if block_given?
                 match_tokens(m[:group][/\A\(\s+(.*(?<!\s))\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group, &block)
               else
                 match_tokens(m[:group][/\A\(\s+(.*(?<!\s))\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group)
               end
        end
      end
    else
      tagstr.scan(tokenize_regex) { |_| r << (block_given? ? block.call(Regexp.last_match) : Regexp.last_match) }
    end
    and_then.respond_to?(:call) ? and_then.call(r) : r
  end

  ##
  # Iterates through tokens, returning the tokens' string values.
  def self.scan_tokens(
    tagstr,
    recurse: false,
    stop_at_group: false,
    and_then: nil,
    &block
  )
    tagstr = tagstr.to_s.unicode_normalize(:nfc).strip
    r = []
    if recurse
      tagstr.scan(tokenize_regex) do |_|
        m = Regexp.last_match
        r << (block_given? ? block.call(m[:prefix] + m[:body]) : m[:prefix] + m[:body]) if m[:group].blank? || stop_at_group
        if m[:group].present?
          r << if block_given?
                 scan_tokens(m[:group][/\A\(\s+(.*(?<!\s))\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group, &block)
               else
                 scan_tokens(m[:group][/\A\(\s+(.*(?<!\s))\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group)
               end
        end
      end
    else
      tagstr.scan(tokenize_regex) do |m|
        m = m.is_a?(String) ? m.strip : Regexp.last_match[0].strip
        r << block_given? ? block.call(m) : m
      end
    end
    and_then.respond_to?(:call) ? and_then.call(r) : r
  end

  ##
  # Scan variant that properly handles groups.
  #
  # This will only pull the tags in `hoisted_metatags` up to the top level
  #
  # `hoisted_metatags`=`TagQuery::GLOBAL_METATAGS`: the metatags to lift out of groups to the top level.
  # `error_on_depth_exceeded`=`false`:
  def self.scan_search(
    query,
    hoisted_metatags: TagQuery::GLOBAL_METATAGS,
    error_on_depth_exceeded: false,
    **kwargs
  )
    depth_limit = TagQuery::DEPTH_LIMIT unless (depth_limit = kwargs.fetch(:depth_limit, nil)).is_a?(Numeric) && depth_limit <= TagQuery::DEPTH_LIMIT
    return error_on_depth_exceeded ? (raise DepthExceededError) : [] if depth_limit < 0
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    # Quick exit if given an empty search or a single group w/ an empty search
    return [] if tagstr.empty? || tagstr[/\A[-~]?\(\s+\)\z/].present?
    matches = []
    hoist_regex_stub = nil
    depth = 1
    # scan_opts = { use_match_data: true, recurse: false, stop_at_group: true }
    scan_opts = { recurse: false, stop_at_group: true }
    match_tokens(tagstr, **scan_opts) do |m| # rubocop:disable Metrics/BlockLength
      # If this query is composed of 1 top-level group with no modifiers, convert to ungrouped.
      if m.begin(:group) == 0 && m.end(:group) == tagstr.length
        return matches = scan_search(
          tagstr = m[:group][/\A\(\s+(.*)\s+\)\z/, 1],
          hoisted_metatags: hoisted_metatags,
          depth_limit: depth_limit -= 1,
          error_on_depth_exceeded: error_on_depth_exceeded,
        )
        # This will change the tag order, putting the hoisted tags in front of the groups that previously contained them
      elsif m[:group].present? && hoisted_metatags.present? &&
            m[:group][/#{hoist_regex_stub ||= "(?>#{hoisted_metatags.inject(nil) { |p, e| p ? "#{p}|#{e}" : e }})"}:\S+/]
        cb = ->(sub_match) do
          # if there's a group w/ a hoisted tag,
          if sub_match[:group].present? && sub_match[:group][/#{hoist_regex_stub}:\S+/]
            raise DepthExceededError if (depth += 1) > depth_limit && error_on_depth_exceeded
            next (depth -= 1 || true) && (sub_match[0].presence&.strip || "") unless (g = sub_match[0].match(/\(\s+(.+)\s+\)/))
            r_out = depth > depth_limit ? "" : match_tokens(g[1].strip, **scan_opts, &cb).inject("") { |p, c| "#{p} #{c}".strip }
            depth -= 1
            "#{sub_match[0][0, g.begin(1)].strip} #{r_out.strip} #{sub_match[0][g.end(1)..].strip}"
          # elsif (sub_match[:metatag].present? && sub_match[:metatag][/\A#{hoist_regex_stub}:"[^"]*"\z/]) ||
          #       (sub_match[:tag].present? && sub_match[:tag][/\A#{hoist_regex_stub}:\S+\z/])
          elsif (sub_match[:metatag].presence || sub_match[:tag].presence || "")[/\A#{hoist_regex_stub}:(?>"[^"]*"|\S+)\z/]
            matches << sub_match[0].strip
            ""
          else
            sub_match[0].strip
          end
        end
        matches << ((outv = cb.call(m)).respond_to?(:flatten) ? outv.flatten : outv)
      else
        matches << m[0].strip
      end
    end
    matches
  end

  ##
  # TODO: If elastic_post_version_query_builder should allow the grouped syntax, modify `elastic_post_version_query_builder.rb:44` to enable
  def self.scan(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    matches = []
    while (m = tagstr.match(/[-~]?\w*?:".*?"/))
      if m.begin(0) >= 0 then matches.push(*tagstr.slice!(0, m.end(0))[0, m.begin(0)].split) end
      matches << m[0]
      ""
    end
    matches.push(*tagstr.split) if tagstr.present?
    matches.uniq
  end

  private_class_method def self.handle_top_level(matches, prefix, strip_prefixes:, distribute_prefixes:, **kwargs)
    if kwargs.fetch(:delimit_groups, true)
      matches.insert(0, "#{strip_prefixes || distribute_prefixes ? '' : prefix}(") << ")"
      kwargs.fetch(:flatten) ? matches : [matches]
    elsif !(strip_prefixes || distribute_prefixes) && prefix.present?
      # TODO: What should be done when not stripping modifiers & not delimiting groups?
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

  ##
  # TODO: Add hoisted tag support
  #
  # TODO: Convert from `match_tokens` to using the regexp directly
  #
  # `strip_duplicates_at_level`: [`false`] Removes any duplicate tags at the
  # current level, and recursively do the same for each group.
  #
  # `delimit_groups`: [`true`] Surround groups w/ parentheses elements. Unless `strip_prefixes` or
  # `distribute_prefixes` are truthy, preserves prefix.
  #
  # `sort_at_level`: [`false`]
  #
  # `normalize_at_level`: [`false`]
  #
  # `error_on_depth_exceeded`: [`false`]
  #
  # Recursive Parameters (SHOULDN'T BE USED BY OUTSIDE METHODS)
  #
  # `depth`: [0]
  def self.scan_recursive(
    query,
    flatten: true,
    strip_prefixes: false,
    distribute_prefixes: nil,
    **kwargs
  )
    kwargs[:depth] = (depth = 1 + kwargs.fetch(:depth, 0))
    if depth > TagQuery::DEPTH_LIMIT
      return raise DepthExceededError if kwargs.fetch(:error_on_depth_exceeded, false)
      return handle_top_level(
        [], nil,
        flatten: flatten, strip_prefixes: strip_prefixes, distribute_prefixes: distribute_prefixes,
        **kwargs
      )
    end
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    matches = []
    last_group_index = -1
    group_ranges = [] if flatten
    top = flatten ? [] : nil
    match_tokens(tagstr, recurse: false, stop_at_group: true) do |m| # rubocop:disable Metrics/BlockLength
      distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
      # If this query is composed of 1 top-level group (with or without modifiers), handle that here
      if (m.begin(:group) == 0 || m.begin(:group) == 1) && m.end(:group) == tagstr.length
        matches = if depth > TagQuery::DEPTH_LIMIT
                    []
                  else
                    TagQuery.scan_recursive(
                      m[:body][/\A\(\s+\)\z/] ? "" : m[:body][/\A\(\s+(.*)\s+\)\z/, 1],
                      flatten: flatten,
                      strip_prefixes: strip_prefixes,
                      distribute_prefixes: distribute_prefixes,
                      **kwargs,
                    )
                  end
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
        return handle_top_level(
          matches, m[:prefix],
          flatten: flatten, strip_prefixes: strip_prefixes, distribute_prefixes: distribute_prefixes,
          **kwargs
        )
      elsif m[:group].present?
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
        value = TagQuery.scan_recursive(
          m[0].strip,
          flatten: flatten,
          strip_prefixes: strip_prefixes,
          distribute_prefixes: distribute_prefixes,
          **kwargs,
        )
        distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
        is_duplicate = false
        dup_check = ->(e) { e.empty? ? value.empty? : e.difference(value).blank? }
        if kwargs.fetch(:strip_duplicates_at_level, false)
          if flatten
            matches.each_cons(value.length) { |e| break if (is_duplicate = dup_check.call(e)) } # rubocop:disable Metrics/BlockNesting
          else
            is_duplicate = matches.any?(&dup_check)
          end
        end
        unless is_duplicate
          # splat regardless of flattening to correctly de-nest value
          if kwargs.fetch(:sort_at_level, false)
            group_ranges << ((last_group_index + 1)..(last_group_index + value.length)) if flatten # rubocop:disable Metrics/BlockNesting
            matches.insert(last_group_index += value.length, *value)
          else
            matches.push(*value)
          end
        end
      else
        prefix = !strip_prefixes && (m[:prefix] || distribute_prefixes) ? resolve_distributed_tag(distribute_prefixes) || m[:prefix] : ""
        value = prefix + (kwargs.fetch(:normalize_at_level, false) ? normalize_single_tag(m[:body]) : m[:body])
        unless kwargs.fetch(:strip_duplicates_at_level, false) && (top || matches).include?(value)
          matches << value
          top << value if flatten
        end
      end
      distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
    end
    if kwargs.fetch(:sort_at_level, false)
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
    return distribution unless distribution
    distribution.include?("-") ? "-" : distribution[-1]
  end

  ##
  # Searches through the given `query` & finds instances of the given `metatags` in no particular
  # order.
  #
  # Can take the following block:
  #
  #   `pre`: the unmatched text between the start/last match and the current match
  #
  #   `contents`: the entire matched metatag, including its name
  #
  #   `post`: the remaining text to test
  #
  #   `tag`: the matched tag name (e.g. `order`, `status`)
  #
  #   `current_value`: the last value output from this block or, if this is the first time block was
  #     called, `initial_value`.
  #
  #   Return the new accumulated value.
  # Returns
  #   if matched, the value generated by the block if given or an array of `contents`
  #   else, `initial_value`
  #
  # NOTE: Due to the nature of the grouping syntax, special handling nested metatags in this method is unneccesary.
  def self.recurse_through_metatags(query, *metatags, initial_value: nil, &block)
    return initial_value if metatags.blank? || (query = query.to_s.unicode_normalize(:nfc).strip).blank?
    mts = metatags.inject(nil) { |p, e| (p ? "#{p}|#{e.to_s.strip}" : e.to_s.strip) if e.present? }
    last_index = 0
    on_success = ->(m) do
      if block_given?
        initial_value = block.call(
          pre: query[0...(last_index + m.begin(0))],
          contents: m[0],
          post: query[(last_index + m.end(0))..],
          tag: m[1],
          current_value: initial_value,
        )
      else
        initial_value = [] unless initial_value.respond_to?(:<<)
        initial_value << m[0]
      end
      last_index += m.end(0)
    end
    while (quoted_m = query.match(/(?:\A|(?<=\s))(\w*):"[^"]*"/, last_index))
      while (m = query[last_index...quoted_m.begin(0)].presence&.match(/(?:\A|(?<=\s))(#{mts}):\S*/))
        on_success.call(m)
      end
      on_success.call(m) if (m = quoted_m[0].match(/\A(#{mts}):"[^"]*"\z/))
      last_index = quoted_m.end(0)
    end
    while (m = query[last_index...query.length].presence&.match(/(?:\A|(?<=\s))(#{mts}):\S*/))
      on_success.call(m)
    end
    initial_value
  end

  def self.has_metatag?(tags, *, recurse: true)
    fetch_metatag(tags, *, recurse: recurse).present?
  end

  ##
  # Pulls the value from the first of the specified metatags found. Accepts strings and arrays.
  def self.fetch_metatag(tags, *metatags, recurse: true)
    return nil if tags.blank?

    # OPTIMIZE: Pass block to `recurse_through_metatags` to return early
    if tags.is_a?(String)
      tags = recurse ? recurse_through_metatags(tags, *metatags) : scan(tags)
    elsif recurse
      tags.join(" ")
      tags = recurse_through_metatags(tags.join(" "), *metatags)
    end
    return nil unless tags
    tags.find do |tag|
      metatag_name, value = tag.split(":", 2)
      return value if metatags.include?(metatag_name)
    end
  end

  def self.has_tag?(tag_array, *, recursive: true, error_on_depth_exceeded: false)
    fetch_tags(tag_array, *, recursive: recursive, error_on_depth_exceeded: error_on_depth_exceeded).any?
  end

  def self.fetch_tags(tag_array, *tags, recursive: true, error_on_depth_exceeded: false)
    if recursive
      tag_array.flat_map do |e|
        if e.to_s.strip.match(/\A[-~]?\(\s.*\s\)\z/)
          scan_recursive(
            e,
            strip_duplicates_at_level: true,
            delimit_groups: false,
            distribute_prefixes: false,
            flatten: true,
            error_on_depth_exceeded: error_on_depth_exceeded,
          ).select { |e2| tags.include?(e2) }
        elsif tags.include?(e)
          e
        end
      end
    else
      tags.select { |tag| tag_array.include?(tag) }
    end.uniq.compact
  end

  def self.ad_tag_string(tag_array)
    if (i = tag_array.index { |v| v == "(" }) && i < (tag_array.index { |v| v == ")" } || -1)
      tag_array = scan_recursive(
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
    fetch_tags(tag_array, *Danbooru.config.ads_keyword_tags).join(" ")
  end

  private_class_method def self.normalize_single_tag(tag)
    TagAlias.active.where(antecedent_name: (tag = Tag.normalize_name(tag)))&.first&.consequent_name || tag
  end

  private

  METATAG_SEARCH_TYPE = {
    "-" => :must_not,
    "~" => :should,
  }.freeze

  DEPTH_LIMIT = 10

  ##
  # TODO: Short-circuit when max tags exceeded?
  # `query`:
  # `process_groups`: `false`
  # `error_on_depth_exceeded`: `false`
  def parse_query(query, process_groups: false, error_on_depth_exceeded: false, depth: 1, **)
    TagQuery.scan_search(query, error_on_depth_exceeded: error_on_depth_exceeded, depth_limit: TagQuery::DEPTH_LIMIT - depth + 1).each do |token| # rubocop:disable Metrics/BlockLength
      # If there's a group, recurse, correctly increment tag_count, then stop processing this token.
      next if /\A([-~]?)\(\s+(.*?)\s+\)\z/.match(token) do |match|
        group = match[2]
        if process_groups
          # thrown = nil
          begin
            group = TagQuery.new(match[2], free_tags_count: @tag_count + @free_tags_count, resolve_aliases: @resolve_aliases, return_with_count_exceeded: true)
          rescue CountExceededWithDataError => e
            group = e
            # thrown = e
          end
          @tag_count += group.tag_count
        else
          @tag_count += TagQuery.scan_recursive(
            match[2],
            flatten: true,
            delimit_groups: false,
            strip_prefixes: true,
            strip_duplicates_at_level: false,
            # IDEA: silently truncate overly nested groups
            # Would require all recursive tokenizers to account for it
            error_on_depth_exceeded: true,
          ).length
        end
        search_type = METATAG_SEARCH_TYPE.fetch(match[1], :must)
        q[:groups][search_type] ||= []
        q[:groups][search_type] << group
        # raise thrown if thrown
        true
      end
      @tag_count += 1 unless Danbooru.config.is_unlimited_tag?(token)
      metatag_name, g2 = token.split(":", 2)

      # Remove quotes from description:"abc def"
      g2 = g2.presence&.delete_prefix('"')&.delete_suffix('"')

      # Short-circuit when there is no metatag or the metatag has no value
      if g2.blank?
        add_tag(token)
        next
      end

      type = METATAG_SEARCH_TYPE.fetch(metatag_name[0], :must)
      case metatag_name.downcase
      when "user", "-user", "~user"
        add_to_query(type, :uploader_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "user_id", "-user_id", "~user_id"
        add_to_query(type, :uploader_ids) do
          g2.to_i
        end

      when "approver", "-approver", "~approver"
        add_to_query(type, :approver_ids, any_none_key: :approver, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "commenter", "-commenter", "~commenter", "comm", "-comm", "~comm"
        add_to_query(type, :commenter_ids, any_none_key: :commenter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noter", "-noter", "~noter"
        add_to_query(type, :noter_ids, any_none_key: :noter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noteupdater", "-noteupdater", "~noteupdater"
        add_to_query(type, :note_updater_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "pool", "-pool", "~pool"
        add_to_query(type, :pool_ids, any_none_key: :pool, value: g2) do
          Pool.name_to_id(g2)
        end

      when "set", "-set", "~set"
        add_to_query(type, :set_ids) do
          post_set_id = PostSet.name_to_id(g2)
          post_set = PostSet.find_by(id: post_set_id)

          next 0 unless post_set
          unless post_set.can_view?(CurrentUser.user)
            raise User::PrivilegeError
          end

          post_set_id
        end

      when "fav", "-fav", "~fav", "favoritedby", "-favoritedby", "~favoritedby"
        add_to_query(type, :fav_ids) do
          favuser = User.find_by_name_or_id(g2) # rubocop:disable Rails/DynamicFindBy

          next 0 unless favuser
          if favuser.hide_favorites?
            raise Favorite::HiddenError
          end

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
        add_to_query(type, :sources, any_none_key: :source, value: g2, wildcard: true) do
          "#{g2}*"
        end

      when "date", "-date", "~date"
        add_to_query(type, :date) { ParseValue.date_range(g2) }

      when "age", "-age", "~age"
        add_to_query(type, :age) { ParseValue.invert_range(ParseValue.range(g2, :age)) }

      when "tagcount", "-tagcount", "~tagcount"
        add_to_query(type, :post_tag_count) { ParseValue.range(g2) }

      when /[-~]?(#{TagCategory::SHORT_NAME_REGEX})tags/
        add_to_query(type, :"#{TagCategory::SHORT_NAME_MAPPING[$1]}_tag_count") { ParseValue.range(g2) }

      when "parent", "-parent", "~parent"
        add_to_query(type, :parent_ids, any_none_key: :parent, value: g2) do
          g2.to_i
        end

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

      when "-status"
        q[:status_must_not] = g2.downcase

      when "filetype", "-filetype", "~filetype", "type", "-type", "~type"
        add_to_query(type, :filetype) { g2.downcase }

      when "description", "-description", "~description"
        add_to_query(type, :description) { g2 }

      when "note", "-note", "~note"
        add_to_query(type, :note) { g2 }

      when "delreason", "-delreason", "~delreason"
        q[:status] ||= "any"
        add_to_query(type, :delreason, wildcard: true) { g2 }

      when "deletedby", "-deletedby", "~deletedby"
        q[:status] ||= "any"
        add_to_query(type, :deleter) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "upvote", "-upvote", "~upvote", "votedup", "-votedup", "~votedup"
        add_to_query(type, :upvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "downvote", "-downvote", "~downvote", "voteddown", "-voteddown", "~voteddown"
        add_to_query(type, :downvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "voted", "-voted", "~voted"
        add_to_query(type, :voted) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

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
    tag = tag.downcase
    if tag.start_with?("-") && tag.length > 1
      if tag.include?("*")
        q[:tags][:must_not] += pull_wildcard_tags(tag.delete_prefix("-"))
      else
        q[:tags][:must_not] << tag.delete_prefix("-")
      end

    elsif tag[0] == "~" && tag.length > 1
      q[:tags][:should] << tag.delete_prefix("~")

    elsif tag.include?("*")
      q[:tags][:should] += pull_wildcard_tags(tag)

    else
      q[:tags][:must] << tag.downcase
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

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
