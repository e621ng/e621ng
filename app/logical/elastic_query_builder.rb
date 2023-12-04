class ElasticQueryBuilder
  attr_accessor :q, :must, :must_not, :should, :order

  def initialize(query)
    @q = query
    @must = [] # These terms are ANDed together
    @must_not = [] # These terms are NOT ANDed together
    @should = [] # These terms are ORed together
    @order = []
    @function_score = nil
    build
  end

  def search
    if must.empty?
      must.push({ match_all: {} })
    end

    query = {
      bool: {
        must: must,
        must_not: must_not,
        should: should,
      },
    }
    query[:bool][:minimum_should_match] = 1 if should.any?

    if @function_score.present?
      @function_score[:query] = query
      query = { function_score: @function_score }
    end
    search_body = {
      query: query,
      sort: order,
      _source: false,
      timeout: "#{CurrentUser.user.try(:statement_timeout) || 3_000}ms",
    }

    model_class.document_store.search(search_body)
  end

  def match_any(*args)
    # Explicitly set minimum should match, even though it may not be required in this context.
    { bool: { minimum_should_match: 1, should: args } }
  end

  def match_none(*args)
    { bool: { must_not: args } }
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

  def add_array_range_relation(key, index_field)
    if q[key]
      must.concat(q[key].map { |x| range_relation(x, index_field) })
    end

    if q[:"#{key}_must_not"]
      must_not.concat(q[:"#{key}_must_not"].map { |x| range_relation(x, index_field) })
    end

    if q[:"#{key}_should"]
      should.concat(q[:"#{key}_should"].map { |x| range_relation(x, index_field) })
    end
  end

  def add_array_relation(key, index_field, any_none_key: nil, action: :term)
    if q[key]
      must.concat(q[key].map { |x| { action => { index_field => x } } })
    end

    if q[:"#{key}_must_not"]
      must_not.concat(q[:"#{key}_must_not"].map { |x| { action => { index_field => x } } })
    end

    if q[:"#{key}_should"]
      should.concat(q[:"#{key}_should"].map { |x| { action => { index_field => x } } })
    end

    if q[any_none_key] == "any"
      must.push({ exists: { field: index_field } })
    elsif q[any_none_key] == "none"
      must_not.push({ exists: { field: index_field } })
    end

    if q[:"#{any_none_key}_should"] == "any"
      should.push({ exists: { field: index_field } })
    elsif q[:"#{any_none_key}_should"] == "none"
      should.push(match_none({ exists: { field: index_field } }))
    end
  end
end
