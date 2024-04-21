# frozen_string_literal: true

class ElasticPostQueryBuilderNew < ElasticQueryBuilder
  BOOLEAN_METATAG_MAPPER = {
    hassource: :source,
    hasdescription: :description,
    ischild: :parent,
    inpool: :pools,
  }.freeze

  TOKENS_TO_SKIP = ["~", "-"].freeze

  def initialize(query_string, resolve_aliases:, free_tags_count:, enable_safe_mode:, always_show_deleted:)
    super(TagQueryNew.new(query_string, resolve_aliases: resolve_aliases, free_tags_count: free_tags_count))
    @enable_safe_mode = enable_safe_mode
    @always_show_deleted = always_show_deleted
    @is_random = false
    @random_seed = nil
    @is_ranked = false
  end

  def model_class
    Post
  end

  def parse_range(val, key, type = :integer, fudged: false)
    range = fudged ? ParseValue.range_fudged(val, type) : ParseValue.range(val, type)

    case range[0]
    when :eq
      { term: { key => range[1] } }
    when :gt, :gte, :lt, :lte
      { range: { key => { range[0] => range[1] } } }
    when :between
      { range: { key => { gte: range[1], lte: range[2] } } }
    when :in
      { terms: { key => range[1] } }
    end
  end

  def range_relation(arr, field)
    return if arr.nil?
    return if arr.size < 2
    return if arr[1].nil?

    case arr[0]
    when :eq
      if arr[1].is_a?(Time)
        { range: { field => { gte: arr[1].beginning_of_day, lte: arr[1].end_of_day } } }
      else
        { term: { field => arr[1] } }
      end
    when :gt
      { range: { field => { gt: arr[1] } } }
    when :gte
      { range: { field => { gte: arr[1] } } }
    when :lt
      { range: { field => { lt: arr[1] } } }
    when :lte
      { range: { field => { lte: arr[1] } } }
    when :in
      { terms: { field => arr[1] } }
    when :between
      { range: { field => { gte: arr[1], lte: arr[2] } } }
    end
  end

  def process_any_none(key, value)
    value = value.downcase

    if %w[any none].include?(value)
      return { exists: { field: key } }, value == "none"
    end

    nil
  end

  def process_boolean(key, value)
    value = value.downcase

    if %w[true false].include?(value)
      return { exists: { field: key } }, value == "false"
    end

    nil
  end

  def meta_tag_parser(token)
    metatag_name, v = token.split(":", 2)

    if v.blank?
      return nil
    end

    v = v.delete_prefix('"').delete_suffix('"')

    case metatag_name.downcase

    when "order"
      case v.downcase
      when "id", "id_asc"
        { as_query: { id: :asc }, is_order_tag: true }

      when "id_desc"
        { as_query: { id: :desc }, is_order_tag: true }

      when "change", "change_desc"
        { as_query: { change_seq: :desc }, is_order_tag: true }

      when "change_asc"
        { as_query: { change_seq: :asc }, is_order_tag: true }

      when "md5"
        { as_query: { md5: :desc }, is_order_tag: true }

      when "md5_asc"
        { as_query: { md5: :asc }, is_order_tag: true }

      when "score", "score_desc"
        { as_query: { score: :desc }, is_order_tag: true }

      when "score_asc"
        { as_query: { score: :asc }, is_order_tag: true }

      when "duration", "duration_desc"
        { as_query: { duration: :desc }, is_order_tag: true }

      when "duration_asc"
        { as_query: { duration: :asc }, is_order_tag: true }

      when "favcount"
        { as_query: { fav_count: :desc }, is_order_tag: true }

      when "favcount_asc"
        { as_query: { fav_count: :asc }, is_order_tag: true }

      when "created_at", "created_at_desc"
        { as_query: { created_at: :desc }, is_order_tag: true }

      when "created_at_asc"
        { as_query: { created_at: :asc }, is_order_tag: true }

      when "updated", "updated_desc"
        { as_query: { updated_at: :desc }, is_order_tag: true }

      when "updated_asc"
        { updated_at: :asc }

      when "comment", "comm"
        { as_query: { commented_at: { order: :desc, missing: :_last } }, is_order_tag: true }

      when "comment_bumped"
        must.push({ exists: { field: "comment_bumped_at" } })
        { as_query: { comment_bumped_at: { order: :desc, missing: :_last } }, is_order_tag: true }

      when "comment_bumped_asc"
        must.push({ exists: { field: "comment_bumped_at" } })
        { as_query: { comment_bumped_at: { order: :asc, missing: :_last } }, is_order_tag: true }

      when "comment_asc", "comm_asc"
        { as_query: { commented_at: { order: :asc, missing: :_last } }, is_order_tag: true }

      when "note"
        { as_query: { noted_at: { order: :desc, missing: :_last } }, is_order_tag: true }

      when "note_asc"
        { as_query: { noted_at: { order: :asc, missing: :_first } }, is_order_tag: true }

      when "mpixels", "mpixels_desc"
        { as_query: { mpixels: :desc }, is_order_tag: true }

      when "mpixels_asc"
        { as_query: { mpixels: :asc }, is_order_tag: true }

      when "portrait"
        { as_query: { aspect_ratio: :asc }, is_order_tag: true }

      when "landscape"
        { as_query: { aspect_ratio: :desc }, is_order_tag: true }

      when "filesize", "filesize_desc"
        { as_query: { file_size: :desc }, is_order_tag: true }

      when "filesize_asc"
        { as_query: { file_size: :asc }, is_order_tag: true }

      when /\A(?<column>#{TagQuery::COUNT_METATAGS.join('|')})(_(?<direction>asc|desc))?\z/i
        column = Regexp.last_match[:column]
        direction = Regexp.last_match[:direction] || "desc"
        { as_query: { column => direction }, is_order_tag: true }

      when "tagcount", "tagcount_desc"
        { as_query: { tag_count: :desc }, is_order_tag: true }

      when "tagcount_asc"
        { as_query: { tag_count: :asc }, is_order_tag: true }

      when /(#{TagCategory::SHORT_NAME_REGEX})tags(?:\Z|_desc)/
        { as_query: { "tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :desc }, is_order_tag: true }

      when /(#{TagCategory::SHORT_NAME_REGEX})tags_asc/
        { as_query: { "tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :asc }, is_order_tag: true }

      when "random"
        { is_random: true, is_order_tag: true }

      when "rank"
        { is_rank: true, is_order_tag: true }
      end

    when "randseed"
      { is_random_seed: true, is_order_tag: true, seed: v.to_i }

    when "user"
      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { uploader: id_or_invalid(user_id) } } }

    when "user_id"
      { as_query: { term: { uploader: v.to_i } } }

    when "approver"
      any_none, negate = process_any_none(:approver, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { approver: id_or_invalid(user_id) } } }

    when "commenter"
      any_none, negate = process_any_none(:commenters, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { commenters: id_or_invalid(user_id) } } }

    when "noter"
      any_none, negate = process_any_none(:noters, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { noters: id_or_invalid(user_id) } } }

    when "noteupdater"
      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { noters: id_or_invalid(user_id) } } }

    when "pool"
      any_none, negate = process_any_none(:pools, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      { as_query: { term: { pools: Pool.name_to_id(v) } } }

    when "set"
      post_set_id = PostSet.name_to_id(v)
      post_set = PostSet.find_by(id: post_set_id)

      return { as_query: { term: { sets: 0 } } } unless post_set

      unless post_set.can_view?(CurrentUser.user)
        raise User::PrivilegeError
      end

      { as_query: { term: { sets: post_set_id } } }

    when "fav", "favoritedby"
      favuser = User.find_by_name_or_id(v) # rubocop:disable Rails/DynamicFindBy

      return { as_query: { term: { faves: 0 } } } unless favuser

      if favuser.hide_favorites?
        raise Favorite::HiddenError
      end

      { as_query: { term: { faves: favuser.id } } }

    when "md5"
      md5s = v.downcase.split(",")[0..99]
      { as_query: { bool: { should: md5s.map { |md5| { term: { md5: md5 } } }, minimum_should_match: 1 } } }
    when "rating"
      { as_query: { term: { rating: v[0]&.downcase || "miss" } } }
    when "locked"
      locked = nil

      case v.downcase
      when "rating"
        locked = :rating_locked
      when "note", "notes"
        locked = :note_locked
      when "status"
        locked = :status_locked
      end

      if locked.nil?
        return { ignore: true }
      end

      { as_query: { term: { locked => true } } }
    when "ratinglocked"
      b = parse_boolean(v)
      { as_query: { term: { rating_locked: b } } }
    when "notelocked"
      b = parse_boolean(v)
      { as_query: { term: { note_locked: b } } }
    when "statuslocked"
      b = parse_boolean(v)
      { as_query: { term: { status_locked: b } } }
    when "id"
      { as_query: parse_range(v, :id) }
    when "width"
      { as_query: parse_range(v, :width) }
    when "height"
      { as_query: parse_range(v, :height) }
    when "mpixels"
      { as_query: parse_range(v, :mpixels, :float, true) }
    when "ratio"
      { as_query: parse_range(v, :aspect_ratio, :ratio) }
    when "duration"
      { as_query: parse_range(v, :duration, :float) }
    when "score"
      { as_query: parse_range(v, :score) }
    when "favcount"
      { as_query: parse_range(v, :fav_count) }
    when "filesize"
      { as_query: parse_range(v, :file_size, :filesize, true) }
    when "change"
      { as_query: parse_range(v, :change_seq) }
    when "source"
      v = "#{v}*"
      any_none, negate = process_any_none(:source, v)

      if any_none
        return { as_query: any_none }, negate
      end

      { as_query: { wildcard: { source: v } } }
    when "date"
      date_range = ParseValue.date_range(v)
      relation = range_relation(date_range, :created_at)

      { as_query: relation }
    when "age"
      age = ParseValue.invert_range(ParseValue.range(v, :age))
      relation = range_relation(age, :created_at)

      { as_query: relation }

    when "tagcount"
      { as_query: parse_range(v, :tag_count) }

    when /(#{TagCategory::SHORT_NAME_REGEX})tags/
      { as_query: parse_range(v, :"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}") }

    when "parent"
      any_none, negate = process_any_none(:parent, v)

      if any_none
        return { as_query: any_none }, negate
      end

      { as_query: { term: { parent: v.to_i } } }

    when "child"
      v = v.downcase
      if v == "none"
        { as_query: { term: { has_children: false } } }
      elsif v == "any"
        { as_query: { term: { has_children: true } } }
      else
        { ignore: true }
      end

    when "isparent"
      { as_query: { term: { has_children: v.downcase == "true" } } }

    when "filetype"
      { as_query: { term: { file_ext: v.downcase } } }

    when "description"
      { as_query: { match_phrase_prefix: { description: v } } }

    when "note"
      { as_query: { match_phrase_prefix: { notes: v } } }

    when "delreason"
      { as_query: { wildcard: { del_reason: v } }, is_status: true }

    when "deletedby"
      user_id = User.name_or_id_to_id(v)
      { as_query: { term: { :deleter= => id_or_invalid(user_id) } }, is_status: true }

    when "voted"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      { as_query: { bool: { should: [{ term: { upvotes: id } }, { term: { downvotes: id } }], minimum_should_match: 1 } } }

    when "upvote", "votedup"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      { as_query: { term: { upvotes: id } } }

    when "downvote", "voteddown"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      { as_query: { term: { downvotes: id } } }

    when "pending_replacements"
      { as_query: { term: { has_pending_replacements: v.downcase == "true" } } }

    when "status"
      case v.downcase
      when "pending"
        { as_query: { term: { pending: true } }, is_status: true }
      when "flagged"
        { as_query: { term: { flagged: true } }, is_status: true }
      when "modqueue"
        { as_query: { bool: { must: [{ term: { deleted: false } }], should: [{ term: { pending: true } }, { term: { flagged: true } }], minimum_should_match: 1 } } }
      when "deleted"
        { as_query: { term: { deleted: true } }, is_status: true }
      when "active"
        { as_query: { bool: { must: [{ term: { pending: false } }, { term: { deleted: false } }, { term: { flagged: false } }] } }, is_status: true }
      when "any"
        { is_status: true }
      else
        { ignore: true }
      end

    when *TagQuery::COUNT_METATAGS
      { as_query: parse_range(v, :"#{metatag_name}") }

    when *TagQuery::BOOLEAN_METATAGS
      boolean, negate = process_boolean(:"#{BOOLEAN_METATAG_MAPPER[:"#{metatag_name}"]}", v)

      if boolean
        return { as_query: boolean }, negate
      end

      { ignore: true }
    end
  end

  def recurse(source, target)
    any_status_mentions = false
    source.each do |tag| # rubocop:disable Metrics/BlockLength
      if tag.is_a? String
        target.push({ term: { tags: tag } })
      elsif tag[:as_query]
        if tag[:is_status]
          any_status_mentions = true
        end
        target.push(tag[:as_query])
      else
        if tag[:is_status]
          any_status_mentions = true
          next
        end

        any_status_mentions ||= tag[:mentions_status]

        new_q = { bool: { must: [], should: [], must_not: tag[:mentions_status] ? [] : [{ term: { deleted: true } }] } }
        if !tag[:must].nil? && tag[:must].any?
          mentions = recurse(tag[:must], new_q[:bool][:must])
          any_status_mentions ||= mentions
        end

        if !tag[:should].nil? && tag[:should].any?
          mentions = recurse(tag[:should], new_q[:bool][:should])
          any_status_mentions ||= mentions
        end

        if !tag[:must_not].nil? && tag[:must_not].any?
          mentions = recurse(tag[:must_not], new_q[:bool][:must_not])
          any_status_mentions ||= mentions
        end

        if new_q[:bool][:should].any?
          new_q[:bool][:minimum_should_match] = 1
        end

        target.push(new_q)
      end
    end

    any_status_mentions
  end

  def parse_meta_tag(cur_query, modifier, previous_negate, token)
    parsed_meta_tag, negate = meta_tag_parser(token)
    if parsed_meta_tag && parsed_meta_tag[:is_order_tag]
      if parsed_meta_tag[:is_random]
        @is_random = true
      elsif parsed_meta_tag[:is_random_seed]
        @random_seed = parsed_meta_tag[:seed]
      elsif parsed_meta_tag[:is_rank]
        @is_ranked = true
      else
        order.push(parsed_meta_tag[:as_query])
      end
    elsif parsed_meta_tag && !parsed_meta_tag[:ignore]
      if parsed_meta_tag[:is_status]
        cur_query[:mentions_status] = true
      end

      if negate
        previous_negate = !previous_negate
      end

      if modifier == 0
        if previous_negate
          cur_query[:must_not].push(parsed_meta_tag)
        else
          cur_query[:must].push(parsed_meta_tag)
        end
      elsif modifier == 1
        if previous_negate
          cur_query[:should].push({ must_not: [parsed_meta_tag] })
        else
          cur_query[:should].push(parsed_meta_tag)
        end
      end
    end
  end

  def recursive_build(group, cur_query = nil, parent = nil)
    if cur_query.nil?
      cur_query = { must: [], should: [], must_not: [], mentions_status: false }
      parent = cur_query
    end

    modifier = 0

    group[:tokens].each_with_index do |token, i| # rubocop:disable Metrics/BlockLength
      if TOKENS_TO_SKIP.include?(token) || token == ""
        next
      end

      previous_token = i > 0 ? group[:tokens][i - 1] : nil
      previous_negate = previous_token == "-"
      next_token = i < group[:tokens].length - 1 ? group[:tokens][i + 1] : nil

      if next_token == "~"
        modifier = 1
      elsif modifier == 1 && next_token != "~" && previous_token != "~"
        if previous_negate
          negated_or = group[:tokens][i - 2] == "~"
          unless negated_or
            modifier = 0
          end
        else
          modifier = 0
        end
      end

      if !token.start_with?("__")
        if parse_meta_tag(cur_query, modifier, previous_negate, token)
          next
        end

        to_push = token.include?("*") ? { should: pull_wildcard_tags(token) } : token

        if modifier == 0
          cur_query[previous_negate ? :must_not : :must].push(to_push)
        elsif modifier == 1
          if !previous_negate
            cur_query[:should].push(to_push)
          elsif token.include?("*")
            cur_query[:should].push({ must_not: to_push })
          else
            cur_query[:should].push({ must_not: [to_push] })
          end
        end
      elsif token.start_with?("__")
        next_group = group[:groups][Integer(token[2..])]

        query = { must: [], should: [], must_not: [], mentions_status: false }

        recursive_build(next_group, query, cur_query)

        if query[:mentions_status] && !parent.nil?
          parent[:mentions_status] = true
        end

        if modifier == 0
          if previous_negate
            cur_query[:must_not].push(query)
          else
            cur_query[:must].push(query)
          end
        elsif modifier == 1
          if previous_negate
            cur_query[:should].push({ must_not: [query] })
          else
            cur_query[:should].push(query)
          end
        end
      end
    end

    cur_query
  end

  def pull_wildcard_tags(tag)
    matches = Tag.name_matches(tag).limit(Danbooru.config.tag_query_limit).order("post_count DESC").pluck(:name)
    matches = ["~~not_found~~"] if matches.empty?
    matches
  end

  def build
    if @enable_safe_mode
      must.push({ term: { rating: "s" } })
    end

    built_query = recursive_build(q, nil)

    any_status_mentions = false

    if recurse(built_query[:must], must)
      any_status_mentions = true
    end

    if recurse(built_query[:should], should)
      any_status_mentions = true
    end

    if recurse(built_query[:must_not], must_not)
      any_status_mentions = true
    end

    unless any_status_mentions
      must_not.push({ term: { deleted: true } })
    end

    if @is_random
      if @random_seed.nil?
        @function_score = {
          random_score: {},
          boost_mode: :replace,
        }
      else
        @function_score = {
          random_score: { seed: q[:random_seed], field: "id" },
          boost_mode: :replace,
        }
      end
    elsif @is_ranked
      @function_score = {
        script_score: {
          script: {
            params: { log3: Math.log(3), date2005_05_24: 1_116_936_000 },
            source: "Math.log(doc['score'].value) / params.log3 + (doc['created_at'].value.millis / 1000 - params.date2005_05_24) / 35000",
          },
        },
      }
      must.push({ range: { score: { gt: 0 } } })
      must.push({ range: { created_at: { gte: 2.days.ago } } })
      order.push({ _score: :desc })
    elsif order.empty?
      order.push({ id: :desc })
    end
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
