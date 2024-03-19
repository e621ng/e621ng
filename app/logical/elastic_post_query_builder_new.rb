# frozen_string_literal: true

class ElasticPostQueryBuilderNew < ElasticQueryBuilder
  def initialize(query_string, resolve_aliases:, free_tags_count:, enable_safe_mode:, always_show_deleted:)
    super(TagQueryNew.new(query_string, resolve_aliases: resolve_aliases, free_tags_count: free_tags_count))
    @enable_safe_mode = enable_safe_mode
    @always_show_deleted = always_show_deleted
  end

  def model_class
    Post
  end

  def recurse(source, target)
    source.each do |tag|
      if tag.is_a? String
        target.push({term: {tags: tag}})
      elsif tag[:as_query]
        target.push(tag[:as_query])
      else
        if tag[:is_status] 
          next 
        end

        new_q = {bool: {must: [], should: [], must_not: !tag[:mentions_status] ? [{term:{:status => :deleted}}] : []}}
        if tag[:must] != nil && tag[:must].any? 
          recurse(tag[:must], new_q[:bool][:must])
        end

        if tag[:should] != nil && tag[:should].any? 
          recurse(tag[:should], new_q[:bool][:should])
        end

        if tag[:must_not] != nil && tag[:must_not].any? 
          recurse(tag[:must_not], new_q[:bool][:must_not])
        end

        if new_q[:bool][:should].any?
          new_q[:bool][:minimum_should_match] = 1
        end

        target.push(new_q)
      end
    end
  end

  def build
    if @enable_safe_mode
      must.push({term: {rating: "s"}})
    end

    recurse(q[:tags][:must], must)
    recurse(q[:tags][:should], should)
    recurse(q[:tags][:must_not], must_not)

    if q[:order_queries].length() == 0
      order.push({id: :desc})
    else
      order = q[:order_queries]
    end
  end
end
