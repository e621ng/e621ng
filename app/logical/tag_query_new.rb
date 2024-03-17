# frozen_string_literal: true

class TagQueryNew < TagQuery

  attr_reader :q, :resolve_aliases

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

  def build_query(group, cur_query)
    if cur_query == nil
      cur_query = { must: [], should: [], must_not: [] }
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

        query = { must: [], should: [], must_not: [] }

        build_query(next_group, query)

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

  def process_any_none(key, value)
    if value == "any" || value == "none"
      return { exists: { :field => key } }, value == "none"
    end

    return nil
  end

  def meta_tag_parser(token)
    metatag_name, v = token.split(":", 2)

    if v.blank?
      return { ignore: true }
    end

    v = v.delete_prefix('"').delete_suffix('"')

    case metatag_name.downcase

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
    else
      return { ignore: true }
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
        cur_group[:groups].push({ tokens: [], groups: [], meta_tags: [] })
        cur_group[:tokens].push("__#{cur_group[:groups].length() - 1}")
      elsif token == ")"
        current_group_index.pop()
      else
        parsed_meta_tag, negate = meta_tag_parser(token)
        if parsed_meta_tag
          if parsed_meta_tag[:is_order_tag]
            if parsed_meta_tag[:is_random]
              group[:order_tags].push({ random: true })
            elsif parsed_meta_tag[:is_random_seed]
              group[:order_tags].push({ random_seed: parsed_meta_tag[:random_seed] })
            elsif parsed_meta_tag[:is_rank]
              group[:order_tags].push(parsed_meta_tag)
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
      end
    end

    if current_group_index.length() != 0
      # ERROR: GROUPS NOT CLOSED!
    end

    @q = { tags: build_query(group, nil), order_queries: group[:order_tags] }
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
