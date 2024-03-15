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
    tagstr.split("") do |char|
      if char == " "
        tokenized.push(token)
        token = ""
      elsif char == "-" && token.length == 0
        tokenized.push(char)
      else
        token += char
      end
    end

    tokenized.push(token)

    tokenized
  end

  def build_query(group, curQuery)
    if curQuery == nil
      curQuery = { must: [], should: [], must_not: [] }
    end

    modifier = 0

    if resolve_aliases
      group[:tokens] = TagAlias.to_aliased(group[:tokens])
    end

    group[:tokens].each_with_index do |token, i|
      if TOKENS_TO_SKIP.include? token || token == ""
        next
      end

      previousToken = i > 0 ? group[:tokens][i - 1] : nil
      previousNegate = previousToken == "-"
      nextToken = i < group[:tokens].length() - 1 ? group[:tokens][i + 1] : nil

      if nextToken == "~"
        modifier = 1
      end

      if !token.start_with?("__")
        if modifier == 0
          if !previousNegate
            if token.include?("*")
              curQuery[:must].push({ should: pull_wildcard_tags(token) })
            else
              curQuery[:must].push(token)
            end
          else
            if token.include?("*")
              curQuery[:must_not].push({ should: pull_wildcard_tags(token) })
            else
              curQuery[:must_not].push(token)
            end
          end
        elsif modifier == 1
          if !previousNegate
            if token.include?("*")
              curQuery[:should].push({ should: pull_wildcard_tags(token) })
            else
              curQuery[:should].push(token)
            end
          else
            if token.include?("*")
              curQuery[:should].push({must_not: { should: pull_wildcard_tags(token) }})
            else
              curQuery[:should].push({must_not: token})
            end
          end
        end
      else
        nextGroup = group[:groups][Integer(token[2..-1])]

        query = { must: [], should: [], must_not: [] }

        build_query(nextGroup, query)

        if modifier == 0
          if !previousNegate
            curQuery[:must].push(query)
          else
            curQuery[:must_not].push(query)
          end
        elsif modifier == 1
          if !previousNegate
            curQuery[:should].push(query)
          else
            curQuery[:should].push({must_not: query})
          end
        end
      end

      if modifier == 1 && nextToken != "~" 
        modifier = 0
      end
    end

    curQuery
  end

  private
  TOKENS_TO_SKIP = ["~", "-"].freeze

  def parse_query(query)
    currentGroupIndex = []
    group = { tokens: [], groups: [], orderTags: [] }

    TagQueryNew.tokenize(query).each do |token|
      curGroup = group
      currentGroupIndex.each do |g|
        curGroup = curGroup[:groups][g]
      end

      if token == "("
        currentGroupIndex.push(curGroup[:groups].length())
        curGroup[:groups].push({ tokens: [], groups: [] })
        curGroup[:tokens].push("__#{curGroup[:groups].length() - 1}")
      elsif token == ")"
        currentGroupIndex.pop()
      else
        curGroup[:tokens].push(token)
      end
    end

    if currentGroupIndex.length() != 0
      # ERROR: GROUPS NOT CLOSED!
    end

    @q = { tags: build_query(group, nil) }
  end
end
