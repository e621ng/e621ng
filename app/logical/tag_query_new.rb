# frozen_string_literal: true

class TagQueryNew < TagQuery
  class UnclosedGroupError < StandardError; end
  class MaxGroupDepthExceededError < StandardError; end
  class MaxTokensAchievedInGroupError < StandardError; end

  attr_reader :q, :resolve_aliases

  MAX_GROUP_DEPTH = 10

  def initialize(query, resolve_aliases: true, free_tags_count: 0)
    @q = nil
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
        if token.length > 0
          tokenized.push(token)
          token = ""
        end
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

    if token.length > 0
      tokenized.push(token)
    end

    tokenized
  end

  private

  def parse_query(query)
    current_group_index = []
    group = { tokens: [], groups: [] }

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
        @tag_count += 1 unless Danbooru.config.is_unlimited_tag?(token) || token == "~" || token.start_with?("order:")
        cur_group[:tokens].push(resolve_aliases ? TagAlias.to_alias(token) : token)

        # If there are more tokens in the group than allowed tags, the searcher is definitely past the tag limit unless they have empty groups, which shouldn't be used anyways
        if cur_group[:tokens].length() > Danbooru.config.tag_query_limit
          raise MaxTokensAchievedInGroupError, "You cannot use more than #{Danbooru.config.tag_query_limit} tokens in a single group"
        end
      end
    end

    if current_group_index.length() != 0
      raise UnclosedGroupError, "A tag search group was not properly closed"
    end

    @q = group
  end
end
