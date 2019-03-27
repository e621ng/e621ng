class PostQueryBuilder
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

    relation.push({bool: {
        should: should,
        must: must,
        must_not: must_not,
    }})
  end

  def saved_search_relation(saved_searches, should)
    if SavedSearch.enabled?
      saved_searches.map do |saved_search|
        if saved_search == "all"
          post_ids = SavedSearch.post_ids_for(CurrentUser.id)
        else
          post_ids = SavedSearch.post_ids_for(CurrentUser.id, label: saved_search)
        end

        post_ids = [] if post_ids.empty?
        should.push({terms: {id: post_ids}})
      end
    end
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

  def sql_like_to_elastic(query)
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

    {wildcard: {source: query}}
  end

  def build
    def should(*args)
      {bool: {should: args}}
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
    add_range_relation(q[:score], :score, must)
    add_range_relation(q[:fav_count], :fav_count, must)
    add_range_relation(q[:filesize], :file_size, must)
    add_range_relation(q[:date], :created_at, must)
    add_range_relation(q[:age], :created_at, must)

    TagCategory.categories.each do |category|
      add_range_relation(q["#{category}_tag_count".to_sym], "tag_count_#{category}", must)
    end

    add_range_relation(q[:post_tag_count], :tag_count, must)

    SEARCHABLE_COUNT_METATAGS.each do |column|
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
      must.push(should({term: {pending: false}},
                       {term: {deleted: false}},
                       {term: {flagged: false}}))
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
        must.push(sql_like_to_elastic(q[:source]))
      end
    end

    if q[:source_neg]
      if q[:source_neg] == "none%"
        relation.push({exists: {field: :source}})
      elsif q[:source_neg] == "http%"
        must_not.push({prefix: {source: "http"}})
      else
        must_not.push(sql_like_to_elastic(q[:source_neg]))
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
      q[:sets].each do |s|
        must.push({term: {sets: s}})
      end
    end
    if q[:sets_neg]
      q[:sets_neg].each do |s|
        must_not.push({term: {sets: s}})
      end
    end

    if q[:saved_searches]
      # TODO
      # saved_search_relation(q[:saved_searches], should)
    end

    if q[:uploader_id_neg]
      must_not.push({term: {uploader_id: q[:uploader_id_neg].to_i}})
    end

    if q[:uploader_id]
      must.push({term: {uploader_id: q[:uploader_id].to_i}})
    end

    if q[:approver_id_neg]
      must_not.push({term: {approver_id: q[:approver_id_neg].to_i}})
    end

    if q[:approver_id]
      if q[:approver_id] == "any"
        must.push({exists: {field: :approver_id}})
      elsif q[:approver_id] == "none"
        must_not.push({exists: {field: :approver_id}})
      else
        must.push({term: {approver_id: q[:approver_id].to_i}})
      end
    end

    if q[:post_id_negated]
      must_not.push({term: {id: q[:post_id_negated].to_i}})
    end

    if q[:parent] == "none"
      must_not.push({exists: {field: :parent_id}})
    elsif q[:parent] == "any"
      must.push({exists: {field: :parent_id}})
    elsif q[:parent]
      must.push(should({term: {id: q[:parent].to_i}},
                       {term: {parent_id: q[:parent].to_i}}))
    end

    if q[:parent_neg_ids]
      neg_ids = q[:parent_neg_ids].map(&:to_i)
      neg_ids.delete(0)
      if neg_ids.present?
        # Negated version of the above
        must_not.push({bool: {
            should: [
                {term: {id: q[:parent].to_i}},
                {term: {parent_id: q[:parent].to_i}},
            ],
        }})
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

    add_tag_string_search_relation(q[:tags], must)

    if q[:favgroups_neg].present?
      q[:favgroups_neg].each do |favgroup_rec|
        favgroup_id = favgroup_rec.to_i
        favgroup = FavoriteGroup.where("favorite_groups.id = ?", favgroup_id).first
        if favgroup
          must_not.push({terms: {id: favgroup.post_id_array}})
        end
      end
    end

    if q[:favgroups].present?
      q[:favgroups].each do |favgroup_rec|
        favgroup_id = favgroup_rec.to_i
        favgroup = FavoriteGroup.where("favorite_groups.id = ?", favgroup_id).first
        if favgroup
          must.push({terms: {id: favgroup.post_id_array}})
        end
      end
    end

    if q[:upvote].present?
      must.push({term: {upvoter_ids: q[:upvote].to_i}})
    end

    if q[:downvote].present?
      must.push({term: {downvoter_ids: q[:downvote].to_i}})
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

    when "score", "score_desc"
      order.concat([{score: :desc}, {id: :desc}])

    when "score_asc"
      order.concat([{score: :asc}, {id: :asc}])

    when "favcount"
      order.concat([{fav_count: :desc}, {id: :desc}])

    when "favcount_asc"
      order.concat([{fav_count: :asc}, {id: :asc}])

    when "created_at", "created_at_desc"
      order.push({created_at: :desc})

    when "created_at_asc"
      order.push({created_at: :asc})

    when "change", "change_desc"
      order.concat([{updated_at: :desc}, {id: :desc}])

    when "change_asc"
      order.concat([{updated_at: :asc}, {id: :asc}])

    when "comment", "comm"
      order.push({commented_at: {order: :desc, missing: :_last}})
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
                  source: "Math.log(doc['score'].value) / params.log3 + (doc['created_at'].date.millis / 1000 - params.date2005_05_24) / 35000",
              },
          },
      }})

      order.push({_score: :desc})

    when "random"
      must.push({function_score: {
          query: {match_all: {}},
          random_score: {},
      }})

      order.push({_score: :desc})

    else
      order.push({id: :desc})
    end

    if must.empty?
      must.push({match_all: {}})
    end

    search_body = {
        query: {bool: {must: must, must_not: must_not}},
        sort: order,
        _source: false,
    }

    Post.__elasticsearch__.search(search_body)
  end
end
