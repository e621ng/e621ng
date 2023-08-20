class ElasticPostQueryBuilder
  LOCK_TYPE_TO_INDEX_FIELD = {
    rating: :rating_locked,
    note: :note_locked,
    status: :status_locked,
  }.freeze

  attr_accessor :query_string, :must, :must_not, :order

  def initialize(query_string)
    @query_string = query_string
    @must = [] # These terms are ANDed together
    @must_not = [] # These terms are NOT ANDed together
    @order = []
  end

  def add_range_relation(arr, field, relation)
    return relation if arr.nil?
    return relation if arr.size < 2
    return relation if arr[1].nil?

    case arr[0]
    when :eq
      if arr[1].is_a?(Time)
        relation.concat([
                            {range: {field => {gte: arr[1].beginning_of_day}}},
                            {range: {field => {lte: arr[1].end_of_day}}},
                        ])
      else
        relation.push({term: {field => arr[1]}})
      end
    when :gt
      relation.push({range: {field => {gt: arr[1]}}})
    when :gte
      relation.push({range: {field => {gte: arr[1]}}})
    when :lt
      relation.push({range: {field => {lt: arr[1]}}})
    when :lte
      relation.push({range: {field => {lte: arr[1]}}})
    when :in
      relation.push({terms: {field => arr[1]}})
    when :between
      relation.concat([
                          {range: {field => {gte: arr[1]}}},
                          {range: {field => {lte: arr[2]}}},
                      ])
    end

    relation
  end

  def add_array_relation(q, key, index_key, any_none_key: nil, action: :term)
    if q[key]
      must.concat(q[key].map { |x| { action => { index_key => x } } })
    end

    if q[:"#{key}_neg"]
      must_not.concat(q[:"#{key}_neg"].map { |x| { action => { index_key => x } } })
    end

    if q[any_none_key] == "any"
      must.push({ exists: { field: index_key } })
    elsif q[any_none_key] == "none"
      must_not.push({ exists: { field: index_key } })
    end
  end

  def add_tag_string_search_relation(tags, relation)
    should = tags[:include].map {|x| {term: {tags: x}}}
    must = tags[:related].map {|x| {term: {tags: x}}}
    must_not = tags[:exclude].map {|x| {term: {tags: x}}}

    search = {bool: {
        should: should,
        must: must,
        must_not: must_not,
    }}
    search[:bool][:minimum_should_match] = 1 if should.size > 0
    relation.push(search)
  end

  def hide_deleted_posts?(q)
    return false if CurrentUser.admin_mode?
    return false if q[:status].in?(%w[deleted active any all])
    return false if q[:status_neg].in?(%w[deleted active any all])
    true
  end

  def prepare_wildcard_query(query)
    # Collapse runs of wildcards for efficiency
    query.squeeze("*")
  end

  def build
    function_score = nil
    def should(*args)
      # Explicitly set minimum should match, even though it may not be required in this context.
      {bool: {minimum_should_match: 1, should: args}}
    end

    if query_string.is_a?(Hash)
      q = query_string
    else
      q = Tag.parse_query(query_string)
    end

    if q[:tag_count].to_i > Danbooru.config.tag_query_limit
      raise ::Post::SearchError.new("You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
    end

    if CurrentUser.safe_mode?
      must.push({term: {rating: "s"}})
    end

    add_range_relation(q[:post_id], :id, must)
    add_range_relation(q[:mpixels], :mpixels, must)
    add_range_relation(q[:ratio], :aspect_ratio, must)
    add_range_relation(q[:width], :width, must)
    add_range_relation(q[:height], :height, must)
    add_range_relation(q[:duration], :duration, must)
    add_range_relation(q[:score], :score, must)
    add_range_relation(q[:fav_count], :fav_count, must)
    add_range_relation(q[:filesize], :file_size, must)
    add_range_relation(q[:change_seq], :change_seq, must)
    add_range_relation(q[:date], :created_at, must)
    add_range_relation(q[:age], :created_at, must)

    TagCategory::CATEGORIES.each do |category|
      add_range_relation(q["#{category}_tag_count".to_sym], "tag_count_#{category}", must)
    end

    add_range_relation(q[:post_tag_count], :tag_count, must)

    Tag::COUNT_METATAGS.map(&:to_sym).each do |column|
      add_range_relation(q[column], column, must)
    end

    if q[:md5]
      must.push(should(*(q[:md5].map {|m| {term: {md5: m}}})))
    end

    if q[:status] == "pending"
      must.push({term: {pending: true}})
    elsif q[:status] == "flagged"
      must.push({term: {flagged: true}})
    elsif q[:status] == "modqueue"
      must.push(should({term: {pending: true}}, {term: {flagged: true}}))
    elsif q[:status] == "deleted"
      must.push({term: {deleted: true}})
    elsif q[:status] == "active"
      must.concat([{term: {pending: false}},
                   {term: {deleted: false}},
                   {term: {flagged: false}}])
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_neg] == "pending"
      must_not.push({term: {pending: true}})
    elsif q[:status_neg] == "flagged"
      must_not.push({term: {flagged: true}})
    elsif q[:status_neg] == "modqueue"
      must_not.push(should({term: {pending: true}},
                      {term: {flagged: true}},
                  ))
    elsif q[:status_neg] == "deleted"
      must_not.push({term: {deleted: true}})
    elsif q[:status_neg] == "active"
      must.push(should({term: {pending: true}},
                       {term: {deleted: true}},
                       {term: {flagged: true}}))
    end

    if hide_deleted_posts?(q)
      must.push({term: {deleted: false}})
    end

    q[:source]&.each do |source|
      if source == "none*"
        must_not.push({exists: {field: :source}})
      elsif source == "http*"
        must.push({prefix: {source: "http"}})
      else
        must.push({ wildcard: { source: prepare_wildcard_query(source) } })
      end
    end

    q[:source_neg]&.each do |source|
      if source == "none*"
        must.push({exists: {field: :source}})
      elsif source == "http*"
        must_not.push({prefix: {source: "http"}})
      else
        must_not.push({ wildcard: { source: prepare_wildcard_query(source) } })
      end
    end

    add_array_relation(q, :uploader_ids, :uploader)
    add_array_relation(q, :approver_ids, :approver, any_none_key: :approver)
    add_array_relation(q, :commenter_ids, :commenters, any_none_key: :commenter)
    add_array_relation(q, :noter_ids, :noters, any_none_key: :noter)
    add_array_relation(q, :note_updater_ids, :noters) # Broken, index field missing
    add_array_relation(q, :pool_ids, :pools, any_none_key: :pool)
    add_array_relation(q, :set_ids, :sets)
    add_array_relation(q, :fav_ids, :faves)
    add_array_relation(q, :parent_ids, :parent, any_none_key: :parent)

    add_array_relation(q, :rating, :rating)
    add_array_relation(q, :filetype, :file_ext)
    add_array_relation(q, :description, :description, action: :match)
    add_array_relation(q, :note, :notes, action: :match)
    add_array_relation(q, :deleter, :deleter)
    add_array_relation(q, :upvote, :upvotes)
    add_array_relation(q, :downvote, :downvotes)

    q[:voted]&.each do |voter_id|
      must.push(should({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } }))
    end

    q[:voted_neg]&.each do |voter_id|
      must_not.push({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } })
    end

    q[:delreason]&.each do |delreason|
      must.push({ wildcard: { del_reason: prepare_wildcard_query(delreason) } })
    end

    q[:delreason_neg]&.each do |delreason|
      must_not.push({ wildcard: { del_reason: prepare_wildcard_query(delreason) } })
    end

    if q[:post_id_neg]
      must_not.push({ term: { id: q[:post_id_neg] } })
    end

    if q[:child] == "none"
      must.push({term: {has_children: false}})
    elsif q[:child] == "any"
      must.push({term: {has_children: true}})
    end

    q[:locked]&.each do |lock_type|
      must.push({ term: { LOCK_TYPE_TO_INDEX_FIELD.fetch(lock_type, "missing") => true } })
    end

    q[:locked_neg]&.each do |lock_type|
      must.push({ term: { LOCK_TYPE_TO_INDEX_FIELD.fetch(lock_type, "missing") => false } })
    end

    if q.include?(:hassource)
      (q[:hassource] ? must : must_not).push({exists: {field: :source}})
    end

    if q.include?(:hasdescription)
      (q[:hasdescription] ? must : must_not).push({exists: {field: :description}})
    end

    if q.include?(:ischild)
      (q[:ischild] ? must : must_not).push({exists: {field: :parent}})
    end

    if q.include?(:isparent)
      must.push({term: {has_children: q[:isparent]}})
    end

    if q.include?(:inpool)
      (q[:inpool] ? must : must_not).push({exists: {field: :pools}})
    end

    if q.include?(:pending_replacements)
      must.push({term: {has_pending_replacements: q[:pending_replacements]}})
    end

    add_tag_string_search_relation(q[:tags], must)

    if q[:order] == "rank"
      must.push({range: {score: {gt: 0}}})
      must.push({range: {created_at: {gte: 2.days.ago}}})
    elsif q[:order] == "landscape" || q[:order] == "portrait" ||
        q[:order] == "mpixels" || q[:order] == "mpixels_desc"
      must.push({exists: {field: :width}})
      must.push({exists: {field: :height}})
    end

    case q[:order]
    when "id", "id_asc"
      order.push({id: :asc})

    when "id_desc"
      order.push({id: :desc})

    when "change", "change_desc"
      order.push({change_seq: :desc})

    when "change_asc"
      order.push({change_seq: :asc})

    when "md5"
      order.push({md5: :desc})

    when "md5_asc"
      order.push({md5: :asc})

    when "score", "score_desc"
      order.concat([{score: :desc}, {id: :desc}])

    when "score_asc"
      order.concat([{score: :asc}, {id: :asc}])

    when "duration", "duration_desc"
      order.concat([{duration: :desc}, {id: :desc}])

    when "duration_asc"
      order.concat([{duration: :asc}, {id: :asc}])

    when "favcount"
      order.concat([{fav_count: :desc}, {id: :desc}])

    when "favcount_asc"
      order.concat([{fav_count: :asc}, {id: :asc}])

    when "created_at", "created_at_desc"
      order.push({created_at: :desc})

    when "created_at_asc"
      order.push({created_at: :asc})

    when "updated", "updated_desc"
      order.concat([{updated_at: :desc}, {id: :desc}])

    when "updated_asc"
      order.concat([{updated_at: :asc}, {id: :asc}])

    when "comment", "comm"
      order.push({commented_at: {order: :desc, missing: :_last}})
      order.push({id: :desc})

    when "comment_bumped"
      must.push({exists: {field: 'comment_bumped_at'}})
      order.push({comment_bumped_at: {order: :desc, missing: :_last}})
      order.push({id: :desc})

    when "comment_bumped_asc"
      must.push({exists: {field: 'comment_bumped_at'}})
      order.push({comment_bumped_at: {order: :asc, missing: :_last}})
      order.push({id: :desc})

    when "comment_asc", "comm_asc"
      order.push({commented_at: {order: :asc, missing: :_last}})
      order.push({id: :asc})

    when "note"
      order.push({noted_at: {order: :desc, missing: :_last}})

    when "note_asc"
      order.push({noted_at: {order: :asc, missing: :_first}})

    when "mpixels", "mpixels_desc"
      order.push({mpixels: :desc})

    when "mpixels_asc"
      order.push({mpixels: :asc})

    when "portrait"
      order.push({aspect_ratio: :asc})

    when "landscape"
      order.push({aspect_ratio: :desc})

    when "filesize", "filesize_desc"
      order.push({file_size: :desc})

    when "filesize_asc"
      order.push({file_size: :asc})

    when /\A(?<column>#{Tag::COUNT_METATAGS.join("|")})(_(?<direction>asc|desc))?\z/i
      column = Regexp.last_match[:column]
      direction = Regexp.last_match[:direction] || "desc"
      order.concat([{column => direction}, {id: direction}])

    when "tagcount", "tagcount_desc"
      order.push({tag_count: :desc})

    when "tagcount_asc"
      order.push({tag_count: :asc})

    when /(#{TagCategory::SHORT_NAME_REGEX})tags(?:\Z|_desc)/
      order.push({"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :desc})

    when /(#{TagCategory::SHORT_NAME_REGEX})tags_asc/
      order.push({"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :asc})

    when "rank"
      must.push({function_score: {
          query: {match_all: {}},
          script_score: {
              script: {
                  params: {log3: Math.log(3), date2005_05_24: 1116936000},
                  source: "Math.log(doc['score'].value) / params.log3 + (doc['created_at'].value.millis / 1000 - params.date2005_05_24) / 35000",
              },
          },
      }})

      order.push({_score: :desc})

    when "random"
      if q[:random].present?
        function_score = {function_score: {
            query: {match_all: {}},
            random_score: {seed: q[:random].to_i, field: 'id'},
            boost_mode: :replace
        }}
      else
        function_score = {function_score: {
            query: {match_all: {}},
            random_score: {},
            boost_mode: :replace
        }}
      end

      order.push({_score: :desc})

    else
      order.push({id: :desc})
    end

    if must.empty?
      must.push({match_all: {}})
    end

    query = {bool: {must: must, must_not: must_not}}
    if function_score.present?
      function_score[:function_score][:query] = query
      query = function_score
    end
    search_body = {
        query: query,
        sort: order,
        _source: false,
        timeout: "#{CurrentUser.user.try(:statement_timeout) || 3_000}ms"
    }

    Post.__elasticsearch__.search(search_body)
  end
end
