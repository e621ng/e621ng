class PostQueryBuilder
  attr_accessor :query_string

  def initialize(query_string)
    @query_string = query_string
  end

  def add_tag_string_search_relation(tags, relation)
    if tags[:include].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') && ARRAY[?]", tags[:include])
    end
    if tags[:related].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') @> ARRAY[?]", tags[:related])
    end
    if tags[:exclude].any?
      relation = relation.where("NOT(string_to_array(posts.tag_string, ' ') && ARRAY[?])", tags[:exclude])
    end

    relation
  end

  def build
    q = Tag.parse_query(query_string)
    relation = Post.all

    if q[:tag_count].to_i > Danbooru.config.tag_query_limit
      raise ::Post::SearchError.new("You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
    end

    relation = relation.add_range_relation(q[:post_id], "posts.id")
    relation = relation.add_range_relation(q[:mpixels], "posts.image_width * posts.image_height / 1000000.0")
    relation = relation.add_range_relation(q[:ratio], "ROUND(1.0 * posts.image_width / GREATEST(1, posts.image_height), 2)")
    relation = relation.add_range_relation(q[:width], "posts.image_width")
    relation = relation.add_range_relation(q[:height], "posts.image_height")
    relation = relation.add_range_relation(q[:score], "posts.score")
    relation = relation.add_range_relation(q[:fav_count], "posts.fav_count")
    relation = relation.add_range_relation(q[:filesize], "posts.file_size")
    relation = relation.add_range_relation(q[:change_seq], "posts.change_seq")
    relation = relation.add_range_relation(q[:date], "posts.created_at")
    relation = relation.add_range_relation(q[:age], "posts.created_at")
    TagCategory.categories.each do |category|
      relation = relation.add_range_relation(q["#{category}_tag_count".to_sym], "posts.tag_count_#{category}")
    end
    relation = relation.add_range_relation(q[:post_tag_count], "posts.tag_count")

    Tag::COUNT_METATAGS.each do |column|
      relation = relation.add_range_relation(q[column.to_sym], "posts.#{column}")
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
    elsif q[:status_neg] == "pending"
      relation = relation.where("posts.is_pending = FALSE")
    elsif q[:status_neg] == "flagged"
      relation = relation.where("posts.is_flagged = FALSE")
    elsif q[:status_neg] == "modqueue"
      relation = relation.where("posts.is_pending = FALSE AND posts.is_flagged = FALSE")
    elsif q[:status_neg] == "deleted"
      relation = relation.where("posts.is_deleted = FALSE")
    elsif q[:status_neg] == "active"
      relation = relation.where("posts.is_pending = TRUE OR posts.is_deleted = TRUE OR posts.is_flagged = TRUE")
    end

    if q[:filetype]
      relation = relation.where("posts.file_ext": q[:filetype])
    end

    if q[:filetype_neg]
      relation = relation.where.not("posts.file_ext": q[:filetype_neg])
    end

    if q[:pool] == "none"
      relation = relation.where("posts.pool_string = ''")
    elsif q[:pool] == "any"
      relation = relation.where("posts.pool_string != ''")
    end

    if q[:uploader_id_neg]
      relation = relation.where.not("posts.uploader_id": q[:uploader_id_neg])
    end

    if q[:uploader_id]
      relation = relation.where("posts.uploader_id": q[:uploader_id])
    end

    if q[:approver_id_neg]
      relation = relation.where.not("posts.approver_id": q[:approver_id_neg])
    end

    if q[:approver_id]
      if q[:approver_id] == "any"
        relation = relation.where("posts.approver_id is not null")
      elsif q[:approver_id] == "none"
        relation = relation.where("posts.approver_id is null")
      else
        relation = relation.where("posts.approver_id": q[:approver_id])
      end
    end

    if q[:commenter_ids]
      q[:commenter_ids].each do |commenter_id|
        if commenter_id == "any"
          relation = relation.where("posts.last_commented_at is not null")
        elsif commenter_id == "none"
          relation = relation.where("posts.last_commented_at is null")
        else
          relation = relation.where("posts.id": Comment.unscoped.where(creator_id: commenter_id).select(:post_id).distinct)
        end
      end
    end

    if q[:noter_ids]
      q[:noter_ids].each do |noter_id|
        if noter_id == "any"
          relation = relation.where("posts.last_noted_at is not null")
        elsif noter_id == "none"
          relation = relation.where("posts.last_noted_at is null")
        else
          relation = relation.where("posts.id": Note.unscoped.where(creator_id: noter_id).select("post_id").distinct)
        end
      end
    end

    if q[:note_updater_ids]
      q[:note_updater_ids].each do |note_updater_id|
        relation = relation.where("posts.id": NoteVersion.unscoped.where(updater_id: note_updater_id).select("post_id").distinct)
      end
    end

    if q[:post_id_negated]
      relation = relation.where("posts.id <> ?", q[:post_id_negated])
    end

    if q[:parent] == "none"
      relation = relation.where("posts.parent_id IS NULL")
    elsif q[:parent] == "any"
      relation = relation.where("posts.parent_id IS NOT NULL")
    elsif q[:parent]
      relation = relation.where("posts.parent_id = ?", q[:parent].to_i)
    end

    if q[:parent_neg_ids]
      neg_ids = q[:parent_neg_ids].map(&:to_i)
      neg_ids.delete(0)
      if neg_ids.present?
        relation = relation.where("posts.id not in (?) and (posts.parent_id is null or posts.parent_id not in (?))", neg_ids, neg_ids)
      end
    end

    if q[:child] == "none"
      relation = relation.where("posts.has_children = FALSE")
    elsif q[:child] == "any"
      relation = relation.where("posts.has_children = TRUE")
    end

    if q[:rating] =~ /^q/
      relation = relation.where("posts.rating = 'q'")
    elsif q[:rating] =~ /^s/
      relation = relation.where("posts.rating = 's'")
    elsif q[:rating] =~ /^e/
      relation = relation.where("posts.rating = 'e'")
    end

    if q[:rating_negated] =~ /^q/
      relation = relation.where("posts.rating <> 'q'")
    elsif q[:rating_negated] =~ /^s/
      relation = relation.where("posts.rating <> 's'")
    elsif q[:rating_negated] =~ /^e/
      relation = relation.where("posts.rating <> 'e'")
    end

    if q[:locked] == "rating"
      relation = relation.where("posts.is_rating_locked = TRUE")
    elsif q[:locked] == "note" || q[:locked] == "notes"
      relation = relation.where("posts.is_note_locked = TRUE")
    elsif q[:locked] == "status"
      relation = relation.where("posts.is_status_locked = TRUE")
    end

    if q[:locked_negated] == "rating"
      relation = relation.where("posts.is_rating_locked = FALSE")
    elsif q[:locked_negated] == "note" || q[:locked_negated] == "notes"
      relation = relation.where("posts.is_note_locked = FALSE")
    elsif q[:locked_negated] == "status"
      relation = relation.where("posts.is_status_locked = FALSE")
    end

    relation = add_tag_string_search_relation(q[:tags], relation)

    if q[:upvote].present?
      user_id = q[:upvote]
      post_ids = PostVote.where(:user_id => user_id).where("score > 0").limit(400).pluck(:post_id)
      relation = relation.where("posts.id": post_ids)
    end

    if q[:downvote].present?
      user_id = q[:downvote]
      post_ids = PostVote.where(:user_id => user_id).where("score < 0").limit(400).pluck(:post_id)
      relation = relation.where("posts.id": post_ids)
    end

    relation
  end
end
