class ElasticPostQueryBuilder
  attr_accessor :query_string, :read_only

  SEARCHABLE_COUNT_METATAGS = [
      :comment_count,
  ].freeze

  def initialize(query_string, read_only: false)
    @query_string = query_string
    @read_only = read_only
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

  def escape_string_for_tsquery(array)
    array.map do |token|
      token.to_escaped_for_tsquery
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

  def table_for_metatag(metatag)
    if metatag.in?(Tag::COUNT_METATAGS)
      metatag[/(?<table>[a-z]+)_count\z/i, :table]
    else
      nil
    end
  end

  def tables_for_query(q)
    metatags = q.keys
    metatags << q[:order].remove(/_(asc|desc)\z/i) if q[:order].present?

    tables = metatags.map {|metatag| table_for_metatag(metatag.to_s)}
    tables.compact.uniq
  end

  def add_joins(q, relation)
    tables = tables_for_query(q)
    relation = relation.with_stats(tables)
    relation
  end

  def hide_deleted_posts?(q)
    return false if CurrentUser.admin_mode?
    return false if q[:status].in?(%w[deleted active any all])
    return false if q[:status_neg].in?(%w[deleted active any all])
    true
  end

  def sql_like_to_elastic(field, query)
    # First escape any existing wildcard characters
    # in the term
    query = query.gsub(/
      (?<!\\)    # not preceded by a backslash
      (?:\\\\)*  # zero or more escaped backslashes
      (\*|\?)    # single asterisk or question mark
    /x, '\\\\\1')

    # Then replace any unescaped SQL LIKE characters
    # with a Kleene star
    query = query.gsub(/
      (?<!\\)    # not preceded by a backslash
      (?:\\\\)*  # zero or more escaped backslashes
      %          # single percent sign
    /x, '*')

    # Collapse runs of wildcards for efficiency
    query = query.gsub(/(?:\*)+\*/, '*')

    {wildcard: {field => query}}
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

    must = [] # These terms are ANDed together
    must_not = [] # These terms are NOT ANDed together
    order = []

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

    TagCategory.categories.each do |category|
      add_range_relation(q["#{category}_tag_count".to_sym], "tag_count_#{category}", must)
    end

    add_range_relation(q[:post_tag_count], :tag_count, must)

    SEARCHABLE_COUNT_METATAGS.each do |column|
      add_range_relation(q[column], column, must)
    end

    if q[:description]
      must.push({match: {description: q[:description]}})
    end
    if q[:description_neg]
      must_not.push({match: {description: q[:description_neg]}})
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
      must.push([{term: {pending: false}},
                 {term: {deleted: false}},
                 {term: {flagged: false}}])
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_neg] == "pending"
      must.push({term: {pending: false}})
    elsif q[:status_neg] == "flagged"
      must.push({term: {flagged: false}})
    elsif q[:status_neg] == "modqueue"
      must.concat([
                      {term: {pending: false}},
                      {term: {flagged: false}},
                  ])
    elsif q[:status_neg] == "deleted"
      must.push({term: {deleted: false}})
    elsif q[:status_neg] == "active"
      must.push(should({term: {pending: true}},
                       {term: {deleted: true}},
                       {term: {flagged: true}}))
    end

    if hide_deleted_posts?(q)
      must.push({term: {deleted: false}})
    end

    if q[:filetype]
      must.push({term: {file_ext: q[:filetype]}})
    end

    if q[:filetype_neg]
      must_not.push({term: {file_ext: q[:filetype_neg]}})
    end

    if q[:source]
      if q[:source] == "none%"
        must_not.push({exists: {field: :source}})
      elsif q[:source] == "http%"
        must.push({prefix: {source: "http"}})
      else
        must.push(sql_like_to_elastic(:source, q[:source]))
      end
    end

    if q[:source_neg]
      if q[:source_neg] == "none%"
        relation.push({exists: {field: :source}})
      elsif q[:source_neg] == "http%"
        must_not.push({prefix: {source: "http"}})
      else
        must_not.push(sql_like_to_elastic(:source, q[:source_neg]))
      end
    end

    if q[:pool] == "none"
      must_not.push({exists: {field: :pools}})
    elsif q[:pool] == "any"
      must.push({exists: {field: :pools}})
    end

    if q[:pools]
      q[:pools].each do |p|
        must.push({term: {pools: p}})
      end
    end
    if q[:pools_neg]
      q[:pools_neg].each do |p|
        must_not.push({term: {pools: p}})
      end
    end

    if q[:sets]
      must.concat(q[:sets].map {|x| {term: {sets: x}}})
    end
    if q[:sets_neg]
      must_not.concat(q[:sets_neg].map {|x| {term: {sets: x}}})
    end

    if q[:fav_ids]
      must.concat(q[:fav_ids].map {|x| {term: {faves: x}}})
    end
    if q[:fav_ids_neg]
      must_not.concat(q[:fav_ids_neg].map {|x| {term: {faves: x}}})
    end

    if q[:uploader_id_neg]
      must_not.concat(q[:uploader_id_neg].map {|x| {term: {uploader: x.to_i}}})
    end

    if q[:uploader_id]
      must.push({term: {uploader: q[:uploader_id].to_i}})
    end

    if q[:approver_id_neg]
      must_not.concat(q[:approver_id_neg].map {|x| {term: {approver: x.to_i}}})
    end

    if q[:approver_id]
      if q[:approver_id] == "any"
        must.push({exists: {field: :approver}})
      elsif q[:approver_id] == "none"
        must_not.push({exists: {field: :approver}})
      else
        must.push({term: {approver: q[:approver_id].to_i}})
      end
    end

    if q[:commenter_ids]
      q[:commenter_ids].each do |commenter_id|
        if commenter_id == "any"
          must.push({exists: {field: :commenters}})
        elsif commenter_id == "none"
          must_not.push({exists: {field: :commenters}})
        else
          must.concat(q[:commenter_ids].map {|x| {term: {commenters: x.to_i}}} )
        end
      end
    end

    if q[:noter_ids]
      q[:noter_ids].each do |noter_id|
        if noter_id == "any"
          must.push({exists: {field: :noters}})
        elsif noter_id == "none"
          must_not.push({exists: {field: :noters}})
        else
          must.concat(q[:noter_ids].map {|x| {term: {noters: x.to_i}}} )
        end
      end
    end

    if q[:note_updater_ids]
      must.concat(q[:note_updater_ids].map {|x| {term: {noters: x.to_i}}} )
    end

    if q[:note]
      must.push({match: {notes: q[:note]}})
    end

    if q[:note_neg]
      must_not.push({match: {notes: q[:note]}})
    end

    if q[:delreason]
      must.push(sql_like_to_elastic(:del_reason, q[:delreason]))
    end

    if q[:delreason_neg]
      must_not.push(sql_like_to_elastic(:del_reason, q[:delreason]))
    end

    if q[:deleter]
      must.push({term: {deleter: q[:deleter].to_i}})
    end

    if q[:deleter_neg]
      must_not.push({term: {deleter: q[:deleter].to_i}})
    end

    if q[:post_id_negated]
      must_not.push({term: {id: q[:post_id_negated].to_i}})
    end

    if q[:parent] == "none"
      must_not.push({exists: {field: :parent}})
    elsif q[:parent] == "any"
      must.push({exists: {field: :parent}})
    elsif q[:parent]
      must.push({term: {parent: q[:parent].to_i}})
    end

    if q[:parent_neg_ids]
      neg_ids = q[:parent_neg_ids].map(&:to_i)
      neg_ids.delete(0)
      if neg_ids.present?
        must_not.push(should(*(neg_ids.map {|p| {term: {parent: p}}})))
      end
    end

    if q[:child] == "none"
      must.push({term: {has_children: false}})
    elsif q[:child] == "any"
      must.push({term: {has_children: true}})
    end

    if q[:pixiv_id]
      if q[:pixiv_id] == "any"
        must.push({exists: {field: :pixiv_id}})
      elsif q[:pixiv_id] == "none"
        must_not.push({exists: {field: :pixiv_id}})
      else
        must.push({term: {pixiv_id: q[:pixiv_id].to_i}})
      end
    end

    if q[:rating] =~ /\Aq/
      must.push({term: {rating: "q"}})
    elsif q[:rating] =~ /\As/
      must.push({term: {rating: "s"}})
    elsif q[:rating] =~ /\Ae/
      must.push({term: {rating: "e"}})
    end

    if q[:rating_negated] =~ /\Aq/
      must_not.push({term: {rating: "q"}})
    elsif q[:rating_negated] =~ /\As/
      must_not.push({term: {rating: "s"}})
    elsif q[:rating_negated] =~ /\Ae/
      must_not.push({term: {rating: "e"}})
    end

    if q[:locked] == "rating"
      must.push({term: {rating_locked: true}})
    elsif q[:locked] == "note" || q[:locked] == "notes"
      must.push({term: {note_locked: true}})
    elsif q[:locked] == "status"
      must.push({term: {status_locked: true}})
    end

    if q[:locked_negated] == "rating"
      must.push({term: {rating_locked: false}})
    elsif q[:locked_negated] == "note" || q[:locked_negated] == "notes"
      must.push({term: {note_locked: false}})
    elsif q[:locked_negated] == "status"
      must.push({term: {status_locked: false}})
    end

    if q.include?(:ratinglocked)
      must.push({term: {rating_locked: q[:ratinglocked]}})
    end

    if q.include?(:notelocked)
      must.push({term: {note_locked: q[:notelocked]}})
    end

    if q.include?(:statuslocked)
      must.push({term: {status_locked: q[:statuslocked]}})
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

    add_tag_string_search_relation(q[:tags], must)

    if q[:upvote].present?
      must.push({term: {upvotes: q[:upvote].to_i}})
    end

    if q[:downvote].present?
      must.push({term: {downvotes: q[:downvote].to_i}})
    end

    if q[:voted].present?
      must.push(should({term: {upvotes: q[:voted].to_i}},
                       {term: {downvotes: q[:voted].to_i}}))
    end
    if q[:neg_upvote].present?
      must_not.push({term: {upvotes: q[:neg_upvote].to_i}})
    end

    if q[:neg_downvote].present?
      must_not.push({term: {downvotes: q[:neg_downvote].to_i}})
    end

    if q[:neg_voted].present?
      must_not.concat([{term: {upvotes: q[:neg_voted].to_i}},
                       {term: {downvotes: q[:neg_voted].to_i}}])
    end

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

    when /\A(?<column>#{SEARCHABLE_COUNT_METATAGS.join("|")})(_(?<direction>asc|desc))?\z/i
      column = Regexp.last_match[:column]
      direction = Regexp.last_match[:direction] || "desc"
      order.concat([{column => direction}, {id: direction}])

    when "tagcount", "tagcount_desc"
      order.push({tag_count: :desc})

    when "tagcount_asc"
      order.push({tag_count: :asc})

    when /(#{TagCategory.short_name_regex})tags(?:\Z|_desc)/
      order.push({"tag_count_#{TagCategory.short_name_mapping[$1]}" => :desc})

    when /(#{TagCategory.short_name_regex})tags_asc/
      order.push({"tag_count_#{TagCategory.short_name_mapping[$1]}" => :asc})

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
