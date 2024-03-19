# frozen_string_literal: true

class TagQueryNew < TagQuery
  class UnclosedGroupError < StandardError; end
  class MaxGroupDepthExceededError < StandardError; end
  class MaxTokensAchievedInGroupError < StandardError; end

  attr_reader :q, :resolve_aliases

  BOOLEAN_METATAG_MAPPER = {
    :hassource => :source,
    :hasdescription => :description,
    :ischild => :parent,
    :inpool => :pools
  }.freeze

  MAX_GROUP_DEPTH = 10

  def initialize(query, resolve_aliases: true, free_tags_count: 0)
    @q = {
      tags: {
        must: [],
        must_not: [],
        should: [],
      },
      order_queries: []
    }
    @resolve_aliases = resolve_aliases
    @tag_count = 0

    parse_query(query)

    if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
      raise CountExceededError, "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time"
    end
  end

  def self.scan(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    quote_delimited = []
    tagstr = tagstr.gsub(/[-~]?\w*?:".*?"/) do |match|
      quote_delimited << match
      ""
    end
    quote_delimited + tagstr.split
  end

  def self.tokenize(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    token = ""
    tokenized = []
    in_quote = false
    tagstr.split("") do |char|
      if char == " " && !in_quote
        tokenized.push(token)
        token = ""
      elsif char == "-" && token.length == 0
        tokenized.push(char)
      elsif char == "\""
        token += char
        if !in_quote
          in_quote = true
        else
          in_quote = false
          tokenized.push(token)
          token = ""
        end
      else
        token += char
      end
    end

    tokenized.push(token)

    tokenized
  end

  def build_query(group, cur_query, parent = nil)
    if cur_query == nil
      cur_query = { must: [], should: [], must_not: [], mentions_status: false }
      parent = cur_query
    end

    modifier = 0

    if resolve_aliases
      group[:tokens].each_with_index do |token, i|
        group[:tokens][i] = TagAlias.to_alias(token)
      end
    end

    group[:tokens].each_with_index do |token, i|
      if TOKENS_TO_SKIP.include? token || token == ""
        next
      end

      previous_token = i > 0 ? group[:tokens][i - 1] : nil
      previous_negate = previous_token == "-"
      next_token = i < group[:tokens].length() - 1 ? group[:tokens][i + 1] : nil

      if next_token == "~"
        modifier = 1
      end

      if !token.start_with?("__") && !token.start_with?("--")
        @tag_count += 1 unless Danbooru.config.is_unlimited_tag?(token)
        if modifier == 0
          if !previous_negate
            if token.include?("*")
              cur_query[:must].push({ should: pull_wildcard_tags(token) })
            else
              cur_query[:must].push(token)
            end
          else
            if token.include?("*")
              cur_query[:must_not].push({ should: pull_wildcard_tags(token) })
            else
              cur_query[:must_not].push(token)
            end
          end
        elsif modifier == 1
          if !previous_negate
            if token.include?("*")
              cur_query[:should].push({ should: pull_wildcard_tags(token) })
            else
              cur_query[:should].push(token)
            end
          else
            if token.include?("*")
              cur_query[:should].push({must_not: { should: pull_wildcard_tags(token) }})
            else
              cur_query[:should].push({must_not: token})
            end
          end
        end
      elsif token.start_with?("__")
        next_group = group[:groups][Integer(token[2..-1])]

        query = { must: [], should: [], must_not: [], mentions_status: false }

        build_query(next_group, query, cur_query)

        if query[:mentions_status] && parent != nil
          parent[:mentions_status] = true
        end

        if modifier == 0
          if !previous_negate
            cur_query[:must].push(query)
          else
            cur_query[:must_not].push(query)
          end
        elsif modifier == 1
          if !previous_negate
            cur_query[:should].push(query)
          else
            cur_query[:should].push({must_not: query})
          end
        end
      elsif token.start_with?("--")
        next_meta_tag = group[:meta_tags][Integer(token[2..-1])]

        if next_meta_tag[:is_status]
          cur_query[:mentions_status] = true
        end

        if modifier == 0
          if !previous_negate
            cur_query[:must].push(next_meta_tag)
          else
            cur_query[:must_not].push(next_meta_tag)
          end
        elsif modifier == 1
          if !previous_negate
            cur_query[:should].push(next_meta_tag)
          else
            cur_query[:should].push({must_not: next_meta_tag})
          end
        end
      end

      if modifier == 1 && next_token != "~" 
        modifier = 0
      end
    end

    cur_query
  end

  private
  TOKENS_TO_SKIP = ["~", "-"].freeze

  def parse_range(val, key, type = :integer, fudged = false)
    range = fudged ? ParseValue.range_fudged(val, type) : ParseValue.range(val, type)

    case range[0]
    when :eq
      return { term: { key => range[1] } }
    when :gt, :gte, :lt, :lte
      return { range: { key => { range[0] => range[1] } } }
    when :between
      return { range: { key => { :gte => range[1], :lte => range[2] } } }
    when :in
      return { terms: { key => range[1] } }
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

    if value == "any" || value == "none"
      return { exists: { :field => key } }, value == "none"
    end

    return nil
  end

  def process_boolean(key, value)
    value = value.downcase

    if value == "true" || value == "false"
      return { exists: { :field => key } }, value == "false"
    end

    return nil
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
        return {as_query: {id: :asc}, is_order_tag: true}
  
      when "id_desc"
        return {as_query: {id: :desc}, is_order_tag: true}
  
      when "change", "change_desc"
        return {as_query: {change_seq: :desc}, is_order_tag: true}
  
      when "change_asc"
        return {as_query: {change_seq: :asc}, is_order_tag: true}
  
      when "md5"
        return {as_query: {md5: :desc}, is_order_tag: true}
  
      when "md5_asc"
        return {as_query: {md5: :asc}, is_order_tag: true}
  
      when "score", "score_desc"
        return {as_query: {score: :desc}, is_order_tag: true}
        order.concat([{score: :desc}, {id: :desc}])
  
      when "score_asc"
        return {as_query: {score: :asc}, is_order_tag: true}
  
      when "duration", "duration_desc"
        return {as_query: {duration: :desc}, is_order_tag: true}
  
      when "duration_asc"
        return {as_query: {duration: :asc}, is_order_tag: true}
  
      when "favcount"
        return {as_query: {fav_count: :desc}, is_order_tag: true}
  
      when "favcount_asc"
        return {as_query: {fav_count: :asc}, is_order_tag: true}
  
      when "created_at", "created_at_desc"
        return {as_query: {created_at: :desc}, is_order_tag: true}
  
      when "created_at_asc"
        return {as_query: {created_at: :asc}, is_order_tag: true}
  
      when "updated", "updated_desc"
        return {as_query: {updated_at: :desc}, is_order_tag: true}
  
      when "updated_asc"
        return {updated_at: :asc}
  
      when "comment", "comm"
        return {as_query: {commented_at: {order: :desc, missing: :_last}}, is_order_tag: true}
  
      when "comment_bumped"
        must.push({exists: {field: 'comment_bumped_at'}})
        return {as_query: {comment_bumped_at: {order: :desc, missing: :_last}}, is_order_tag: true}
  
      when "comment_bumped_asc"
        must.push({exists: {field: 'comment_bumped_at'}})
        return {as_query: {comment_bumped_at: {order: :asc, missing: :_last}}, is_order_tag: true}
  
      when "comment_asc", "comm_asc"
        return {as_query: {commented_at: {order: :asc, missing: :_last}}, is_order_tag: true}
  
      when "note"
        return {as_query: {noted_at: {order: :desc, missing: :_last}}, is_order_tag: true}
  
      when "note_asc"
        return {as_query: {noted_at: {order: :asc, missing: :_first}}, is_order_tag: true}
  
      when "mpixels", "mpixels_desc"
        return {as_query: {mpixels: :desc}, is_order_tag: true}
  
      when "mpixels_asc"
        return {as_query: {mpixels: :asc}, is_order_tag: true}
  
      when "portrait"
        return {as_query: {aspect_ratio: :asc}, is_order_tag: true}
  
      when "landscape"
        return {as_query: {aspect_ratio: :desc}, is_order_tag: true}
  
      when "filesize", "filesize_desc"
        return {as_query: {file_size: :desc}, is_order_tag: true}
  
      when "filesize_asc"
        return {as_query: {file_size: :asc}, is_order_tag: true}
  
      when /\A(?<column>#{TagQuery::COUNT_METATAGS.join('|')})(_(?<direction>asc|desc))?\z/i
        column = Regexp.last_match[:column]
        direction = Regexp.last_match[:direction] || "desc"
        order.concat([{column => direction}, {id: direction}])
  
      when "tagcount", "tagcount_desc"
        return {as_query: {tag_count: :desc}, is_order_tag: true}
  
      when "tagcount_asc"
        return {as_query: {tag_count: :asc}, is_order_tag: true}
  
      when /(#{TagCategory::SHORT_NAME_REGEX})tags(?:\Z|_desc)/
        return {as_query: {"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :desc}, is_order_tag: true}
  
      when /(#{TagCategory::SHORT_NAME_REGEX})tags_asc/
        return {as_query: {"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :asc}, is_order_tag: true}
  
      when "random"
        return {is_random: true, is_order_tag: true}

      when "rank"
        return {is_rank: true, is_order_tag: true}
      end

    when "randseed"
      return { is_random_seed: true, is_order_tag: true, seed: v.to_i }

    when "user"
      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:uploader => id_or_invalid(user_id)}} }

    when "user_id"
      return { as_query: {term: {:uploader => v.to_i}} }

    when "approver"
      any_none, negate = process_any_none(:approver, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:approver => id_or_invalid(user_id)}} }

    when "commenter"
      any_none, negate = process_any_none(:commenters, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:commenters => id_or_invalid(user_id)}} }

    when "noter"
      any_none, negate = process_any_none(:noters, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:noters => id_or_invalid(user_id)}} }

    when "noteupdater"
      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:noters => id_or_invalid(user_id)}} }

    when "pool"
      any_none, negate = process_any_none(:pools, v.downcase)

      if any_none
        return { as_query: any_none }, negate
      end

      return { as_query: {term: {:pools => Pool.name_to_id(v)}} }

    when "set"
      post_set_id = PostSet.name_to_id(v)
      post_set = PostSet.find_by(id: post_set_id)

      return { as_query: {term: {:sets => 0}} } unless post_set

      unless post_set.can_view?(CurrentUser.user)
        raise User::PrivilegeError
      end

      return { as_query: {term: {:sets => post_set_id}} }

    when "fav", "favoritedby"
      favuser = User.find_by_name_or_id(v)

      return { as_query: {term: {:faves => 0}} } unless favuser

      if favuser.hide_favorites?
        raise Favorite::HiddenError
      end

      return { as_query: {term: {:faves => favuser.id}} }

    when "md5"
      md5s = v.downcase.split(",")[0..99]
      return { as_query: { bool: { should: md5s.map { |md5| { term: { :md5 => md5 } } }, minimum_should_match: 1 } } }
    when "rating"
      return { as_query: { term: { :rating => v[0]&.downcase || "miss" } } }
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

      if locked == nil
        return { ignore: true }
      end

      return { as_query: { term: { locked => true } } }
    when "ratinglocked"
      b = parse_boolean(v)
      return { as_query: { term: { :rating_locked => b } } }
    when "notelocked"
      b = parse_boolean(v)
      return { as_query: { term: { :note_locked => b } } }
    when "statuslocked"
      b = parse_boolean(v)
      return { as_query: { term: { :status_locked => b } } }
    when "id"
      return { as_query: parse_range(v, :id) }
    when "width"
      return { as_query: parse_range(v, :width) }
    when "height"
      return { as_query: parse_range(v, :height) }
    when "mpixels"
      return { as_query: parse_range(v, :mpixels, :float, true) }
    when "ratio"
      return { as_query: parse_range(v, :aspect_ratio, :ratio) }
    when "duration"
      return { as_query: parse_range(v, :duration, :float) }
    when "score"
      return { as_query: parse_range(v, :score) }
    when "favcount"
      return { as_query: parse_range(v, :fav_count) }
    when "filesize"
      return { as_query: parse_range(v, :file_size, :filesize, true) }
    when "change"
      return { as_query: parse_range(v, :change_seq) }
    when "source"
      v = "#{v}*"
      any_none, negate = process_any_none(:source, v)

      if any_none
        return { as_query: any_none }, negate
      end

      return { as_query: {wildcard: {:source => v}} }
    when "date"
      date_range = ParseValue.date_range(v)
      relation = range_relation(date_range, :created_at)

      return { as_query: relation }
    when "age"
      age = ParseValue.invert_range(ParseValue.range(v, :age))
      relation = range_relation(age, :created_at)

      return { as_query: relation }

    when "tagcount"
      return { as_query: parse_range(v, :tag_count) }

    when /(#{TagCategory::SHORT_NAME_REGEX})tags/
      return { as_query: parse_range(v, :"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}") }

    when "parent"
      any_none, negate = process_any_none(:parent, v)

      if any_none
        return { as_query: any_none }, negate
      end

      return { as_query: {term: {:parent => v.to_i}} }

    when "child"
      v = v.downcase
      if v == "none"
        return { as_query: {term: {:has_children => false}} }
      elsif v == "any"
        return { as_query: {term: {:has_children => true}} }
      else
        return { ignore: true }
      end

    when "isparent"
      return { as_query: {term: {:has_children => v.downcase == "true"}} }

    when "filetype"
      return { as_query: {term: {:file_ext => v.downcase}} }

    when "description"
      return { as_query: {match_phrase_prefix: {:description => v}} }

    when "note"
      return { as_query: {match_phrase_prefix: {:notes => v}} }

    when "delreason"
      return { as_query: {wildcard: {:del_reason => v}}, is_status: true }

    when "deletedby"
      user_id = User.name_or_id_to_id(v)
      return { as_query: {term: {:deleter= => id_or_invalid(user_id)}}, is_status: true }

    when "voted"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      return { as_query: { bool: { should: [{term: {:upvotes => id}}, {term: {:downvotes => id}}], minimum_should_match: 1 } } }

    when "upvote", "votedup"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      return { as_query: { term: {:upvotes => id}} }

    when "downvote", "voteddown"
      if CurrentUser.is_moderator?
        user_id = User.name_or_id_to_id(v)
      elsif CurrentUser.is_member?
        user_id = CurrentUser.id
      end
      id = id_or_invalid(user_id)
      return { as_query: { term: {:downvotes => id}} }

    when "pending_replacements"
      return { as_query: {term: {:has_pending_replacements => v.downcase == "true"}} }

    when "status"
      case v.downcase
      when "pending"
        return { as_query: {term: {:pending => true}}, is_status: true }
      when "flagged"
        return { as_query: {term: {:flagged => true}}, is_status: true }
      when "modqueue"
        return { as_query: { bool: { must: [{term: {:deleted => false}}], should: [{term: {:pending => true}}, {term: {:flagged => true}}], minimum_should_match: 1 } } }
      when "deleted"
        return { as_query: {term: {:deleted => true}}, is_status: true }
      when "active"
        return { as_query: { bool: { must: [{term: {:pending => false}}, {term: {:deleted => false}}, {term: {:flagged => false}}]}}, is_status: true }
      when "any"
        return { is_status: true }
      else
        return { ignore: true }
      end

    when *COUNT_METATAGS
      return { as_query: parse_range(v, :"#{metatag_name}") }

    when *BOOLEAN_METATAGS
      boolean, negate = process_boolean(:"#{BOOLEAN_METATAG_MAPPER[:"#{metatag_name}"]}", v)

      if boolean
        return { as_query: boolean }, negate
      end

      return { ignore: true }
    else
      return nil
    end
  end

  def parse_query(query)
    current_group_index = []
    group = { tokens: [], groups: [], order_tags: [], meta_tags: [] }

    TagQueryNew.tokenize(query).each do |token|
      cur_group = group
      current_group_index.each do |g|
        cur_group = cur_group[:groups][g]
      end

      if token == "("
        current_group_index.push(cur_group[:groups].length())
        if current_group_index.length() > MAX_GROUP_DEPTH
          raise MaxGroupDepthExceededError, "Exceeded the max group depth of: #{MAX_GROUP_DEPTH}"
        end
        cur_group[:groups].push({ tokens: [], groups: [], meta_tags: [] })
        cur_group[:tokens].push("__#{cur_group[:groups].length() - 1}")
      elsif token == ")"
        current_group_index.pop()
      else
        parsed_meta_tag, negate = meta_tag_parser(token)
        if parsed_meta_tag
          if parsed_meta_tag[:is_order_tag]
            if parsed_meta_tag[:is_random]
              group[:random_order] = true
            elsif parsed_meta_tag[:is_random_seed]
              group[:random_seed] = parsed_meta_tag[:seed]
            elsif parsed_meta_tag[:is_rank]
              group[:rank_order] = true
            else
              group[:order_tags].push(parsed_meta_tag[:as_query])
            end
          elsif !parsed_meta_tag[:ignore]
            cur_group[:meta_tags].push(parsed_meta_tag)
            if negate
              if cur_group[:tokens][cur_group[:tokens].length()] == "-" then
                cur_group[:tokens].pop()
              else
                cur_group[:tokens].push("-")
              end
            end
            cur_group[:tokens].push("--#{cur_group[:meta_tags].length - 1}")
          end
        else
          cur_group[:tokens].push(token)
        end

        # If there are more tokens in the group than allowed tags, the searcher is definitely past the tag limit unless they have empty groups, which shouldn't be used anyways
        if cur_group[:tokens].length() > Danbooru.config.tag_query_limit
          raise MaxTokensAchievedInGroupError, "You cannot use more than #{Danbooru.config.tag_query_limit} tokens in a single group"
        end
      end
    end

    if current_group_index.length() != 0
      raise UnclosedGroupError, "A tag search group was not properly closed"
    end

    @q = { tags: build_query(group, nil), order_queries: group[:order_tags], is_random: group[:random_order], random_seed: group[:random_seed], is_ranked: group[:rank_order] }
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
