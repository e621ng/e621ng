class PostQueryBuilder
  attr_accessor :query_string

  def initialize(query_string)
    @query_string = query_string
  end

  def add_tag_string_search_relation(tags, relation)
    if tags[:must].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') @> ARRAY[?]", tags[:must])
    end
    if tags[:must_not].any?
      relation = relation.where("NOT(string_to_array(posts.tag_string, ' ') && ARRAY[?])", tags[:must_not])
    end
    if tags[:should].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') && ARRAY[?]", tags[:should])
    end

    relation
  end

  def add_array_range_relation(relation, values, field)
    values&.each do |value|
      relation = relation.add_range_relation(value, field)
    end
    relation
  end

  def search
    q = TagQuery.new(query_string)
    relation = Post.all

    relation = relation.add_range_relation(q[:post_id], "posts.id")
    relation = add_array_range_relation(relation, q[:mpixels], "posts.image_width * posts.image_height / 1000000.0")
    relation = add_array_range_relation(relation, q[:mpixels], "posts.image_width * posts.image_height / 1000000.0")
    relation = add_array_range_relation(relation, q[:ratio], "ROUND(1.0 * posts.image_width / GREATEST(1, posts.image_height), 2)")
    relation = add_array_range_relation(relation, q[:width], "posts.image_width")
    relation = add_array_range_relation(relation, q[:height], "posts.image_height")
    relation = add_array_range_relation(relation, q[:score], "posts.score")
    relation = add_array_range_relation(relation, q[:fav_count], "posts.fav_count")
    relation = add_array_range_relation(relation, q[:filesize], "posts.file_size")
    relation = add_array_range_relation(relation, q[:change_seq], "posts.change_seq")
    relation = add_array_range_relation(relation, q[:date], "posts.created_at")
    relation = add_array_range_relation(relation, q[:age], "posts.created_at")
    TagCategory::CATEGORIES.each do |category|
      relation = add_array_range_relation(relation, q["#{category}_tag_count".to_sym], "posts.tag_count_#{category}")
    end
    relation = add_array_range_relation(relation, q[:post_tag_count], "posts.tag_count")

    TagQuery::COUNT_METATAGS.each do |column|
      relation = add_array_range_relation(relation, q[column.to_sym], "posts.#{column}")
    end

    if q[:md5]
      relation = relation.where("posts.md5": q[:md5])
    end

    if q[:status] == "pending"
      relation = relation.where("posts.is_pending = TRUE")
    elsif q[:status] == "flagged"
      relation = relation.where("posts.is_flagged = TRUE")
    elsif q[:status] == "modqueue"
      relation = relation.where("posts.is_pending = TRUE OR posts.is_flagged = TRUE")
    elsif q[:status] == "deleted"
      relation = relation.where("posts.is_deleted = TRUE")
    elsif q[:status] == "active"
      relation = relation.where("posts.is_pending = FALSE AND posts.is_deleted = FALSE AND posts.is_flagged = FALSE")
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_must_not] == "pending"
      relation = relation.where("posts.is_pending = FALSE")
    elsif q[:status_must_not] == "flagged"
      relation = relation.where("posts.is_flagged = FALSE")
    elsif q[:status_must_not] == "modqueue"
      relation = relation.where("posts.is_pending = FALSE AND posts.is_flagged = FALSE")
    elsif q[:status_must_not] == "deleted"
      relation = relation.where("posts.is_deleted = FALSE")
    elsif q[:status_must_not] == "active"
      relation = relation.where("posts.is_pending = TRUE OR posts.is_deleted = TRUE OR posts.is_flagged = TRUE")
    end

    q[:filetype]&.each do |filetype|
      relation = relation.where("posts.file_ext": filetype)
    end

    q[:filetype_must_not]&.each do |filetype|
      relation = relation.where.not("posts.file_ext": filetype)
    end

    if q[:pool] == "none"
      relation = relation.where("posts.pool_string = ''")
    elsif q[:pool] == "any"
      relation = relation.where("posts.pool_string != ''")
    end

    q[:uploader_ids]&.each do |uploader_id|
      relation = relation.where("posts.uploader_id": uploader_id)
    end

    q[:uploader_ids_must_not]&.each do |uploader_id|
      relation = relation.where.not("posts.uploader_id": uploader_id)
    end

    if q[:approver] == "any"
      relation = relation.where("posts.approver_id is not null")
    elsif q[:approver] == "none"
      relation = relation.where("posts.approver_id is null")
    end

    q[:approver_ids]&.each do |approver_id|
      relation = relation.where("posts.approver_id": approver_id)
    end

    q[:approver_ids_must_not]&.each do |approver_id|
      relation = relation.where.not("posts.approver_id": approver_id)
    end

    if q[:commenter] == "any"
      relation = relation.where("posts.last_commented_at is not null")
    elsif q[:commenter] == "none"
      relation = relation.where("posts.last_commented_at is null")
    end

    if q[:noter] == "any"
      relation = relation.where("posts.last_noted_at is not null")
    elsif q[:noter] == "none"
      relation = relation.where("posts.last_noted_at is null")
    end

    if q[:post_id_must_not]
      relation = relation.where("posts.id <> ?", q[:post_id_must_not])
    end

    if q[:parent] == "none"
      relation = relation.where("posts.parent_id IS NULL")
    elsif q[:parent] == "any"
      relation = relation.where("posts.parent_id IS NOT NULL")
    end

    q[:parent_ids]&.each do |parent_id|
      relation = relation.where("posts.parent_id = ?", parent_id)
    end

    q[:parent_ids_must_not]&.each do |parent_id|
      relation = relation.where.not("posts.parent_id = ?", parent_id)
    end

    if q[:child] == "none"
      relation = relation.where("posts.has_children = FALSE")
    elsif q[:child] == "any"
      relation = relation.where("posts.has_children = TRUE")
    end

    q[:rating]&.each do |rating|
      relation = relation.where("posts.rating = ?", rating)
    end

    q[:rating_must_not]&.each do |rating|
      relation = relation.where("posts.rating = ?", rating)
    end

    add_tag_string_search_relation(q[:tags], relation)
  end
end
