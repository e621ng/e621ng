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
    any_status_mentions = false
    source.each do |tag|
      if tag.is_a? String
        target.push({term: {tags: tag}})
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

        any_status_mentions = any_status_mentions || tag[:mentions_status]

        new_q = {bool: {must: [], should: [], must_not: !tag[:mentions_status] ? [{term:{:deleted => true}}] : []}}
        if tag[:must] != nil && tag[:must].any? 
          mentions = recurse(tag[:must], new_q[:bool][:must])
          any_status_mentions = any_status_mentions || mentions
        end

        if tag[:should] != nil && tag[:should].any? 
          mentions = recurse(tag[:should], new_q[:bool][:should])
          any_status_mentions = any_status_mentions || mentions
        end

        if tag[:must_not] != nil && tag[:must_not].any? 
          mentions = recurse(tag[:must_not], new_q[:bool][:must_not])
          any_status_mentions = any_status_mentions || mentions
        end

        if new_q[:bool][:should].any?
          new_q[:bool][:minimum_should_match] = 1
        end

        target.push(new_q)
      end
    end

    return any_status_mentions
  end

  def build
    if @enable_safe_mode
      must.push({term: {rating: "s"}})
    end

    any_status_mentions = false

    if recurse(q[:tags][:must], must)
      any_status_mentions = true
    end

    if recurse(q[:tags][:should], should)
      any_status_mentions = true
    end


    if recurse(q[:tags][:must_not], must_not)
      any_status_mentions = true
    end

    if !any_status_mentions
      must_not.push({term: {:deleted => true}})
    end

    if q[:is_random]
      if q[:random_seed].present?
        @function_score = {
          random_score: { seed: q[:random_seed], field: "id" },
          boost_mode: :replace,
        }
      else
        @function_score = {
          random_score: {},
          boost_mode: :replace,
        }
      end
    elsif q[:is_ranked]
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
    elsif q[:order_queries].length() == 0
      order.push({id: :desc})
    else
      @order = q[:order_queries]
    end
  end
end
