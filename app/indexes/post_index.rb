# frozen_string_literal: true

module PostIndex
  def self.included(base)
    base.document_store.index = {
      settings: {
        index: {
          number_of_shards: 5,
          number_of_replicas: 1,
          max_result_window: 250_000,
        },
      },
      mappings: {
        dynamic: false,
        properties: {
          created_at: { type: "date" },
          updated_at: { type: "date" },
          commented_at: { type: "date" },
          comment_bumped_at: { type: "date" },
          noted_at: { type: "date" },
          id: { type: "integer" },
          up_score: { type: "integer" },
          down_score: { type: "integer" },
          score: { type: "integer" },
          fav_count: { type: "integer" },
          tag_count: { type: "integer" },
          change_seq: { type: "long" },

          tag_count_general: { type: "integer" },
          tag_count_artist: { type: "integer" },
          tag_count_character: { type: "integer" },
          tag_count_copyright: { type: "integer" },
          tag_count_meta: { type: "integer" },
          tag_count_species: { type: "integer" },
          tag_count_invalid: { type: "integer" },
          tag_count_lore: { type: "integer" },
          comment_count: { type: "integer" },
          dis_count: { type: "integer" },

          file_size: { type: "integer" },
          parent: { type: "integer" },
          pools: { type: "integer" },
          sets: { type: "integer" },
          commenters: { type: "integer" },
          noters: { type: "integer" },
          faves: { type: "integer" },
          upvotes: { type: "integer" },
          downvotes: { type: "integer" },
          children: { type: "integer" },
          uploader: { type: "integer" },
          approver: { type: "integer" },
          disapprover: { type: "integer" },
          deleter: { type: "integer" },
          width: { type: "integer" },
          height: { type: "integer" },
          mpixels: { type: "float" },
          aspect_ratio: { type: "float" },
          duration: { type: "float" },

          tags: { type: "keyword" },
          md5: { type: "keyword" },
          rating: { type: "keyword" },
          file_ext: { type: "keyword" },
          source: { type: "keyword" },
          description: { type: "text" },
          notes: { type: "text" },
          del_reason: { type: "keyword" },

          rating_locked: { type: "boolean" },
          note_locked: { type: "boolean" },
          status_locked: { type: "boolean" },
          flagged: { type: "boolean" },
          pending: { type: "boolean" },
          deleted: { type: "boolean" },
          has_children: { type: "boolean" },
          has_pending_replacements: { type: "boolean" },
        },
      },
    }

    base.document_store.extend ClassMethods
  end

  module ClassMethods
    # Denormalizing the input can be made significantly more
    # efficient when processing large numbers of posts.
    def import(options = {})
      batch_size = options[:batch_size] || 1000

      relation = all
      relation = relation.where("id >= ?", options[:from]) if options[:from]
      relation = relation.where("id <= ?", options[:to])   if options[:to]
      relation = relation.where(options[:query])           if options[:query]

      # PG returns {array,results,like,this}, so we need to parse it
      array_parse = proc do |pid, array|
        [pid, array[1..-2].split(",")]
      end

      relation.find_in_batches do |batch|
        post_ids = batch.map(&:id).join(",")

        comments_sql = <<-SQL
          SELECT post_id, count(*) FROM comments
          WHERE post_id IN (#{post_ids})
          GROUP BY post_id
        SQL
        pools_sql = <<-SQL
          SELECT post_id, ( SELECT COALESCE(array_agg(id), '{}'::int[]) FROM pools WHERE post_ids @> ('{}'::int[] || post_id) )
          FROM (SELECT unnest('{#{post_ids}}'::int[])) as input_list(post_id);
        SQL
        sets_sql = <<-SQL
          SELECT post_id, ( SELECT COALESCE(array_agg(id), '{}'::int[]) FROM post_sets WHERE post_ids @> ('{}'::int[] || post_id) )
          FROM (SELECT unnest('{#{post_ids}}'::int[])) as input_list(post_id);
        SQL
        commenter_sql = <<-SQL
          SELECT post_id, array_agg(distinct creator_id) FROM comments
          WHERE post_id IN (#{post_ids}) AND is_hidden = false
          GROUP BY post_id
        SQL
        noter_sql = <<-SQL
          SELECT post_id, array_agg(distinct creator_id) FROM notes
          WHERE post_id IN (#{post_ids}) AND is_active = true
          GROUP BY post_id
        SQL
        faves_sql = <<-SQL
          SELECT post_id, array_agg(user_id) FROM favorites
          WHERE post_id IN (#{post_ids})
          GROUP BY post_id
        SQL
        votes_sql = <<-SQL
          SELECT post_id, array_agg(user_id), array_agg(score) FROM post_votes
          WHERE post_id IN (#{post_ids})
          GROUP BY post_id
        SQL
        child_sql = <<-SQL
          SELECT parent_id, array_agg(id) FROM posts
          WHERE parent_id IN (#{post_ids})
          GROUP BY parent_id
        SQL
        note_sql = <<-SQL
          SELECT post_id, body FROM notes
          WHERE post_id IN (#{post_ids})
        SQL
        deletion_sql = <<-SQL
          SELECT pf.post_id, pf.creator_id, LOWER(pf.reason) as reason FROM
            (SELECT MAX(id) as mid, post_id
             FROM post_flags
             WHERE post_id IN (#{post_ids}) AND is_resolved = false AND is_deletion = true
             GROUP BY post_id) pfi
          INNER JOIN post_flags pf ON pf.id = pfi.mid;
        SQL
        pending_replacements_sql = <<-SQL
          SELECT DISTINCT p.id, CASE WHEN pr.post_id IS NULL THEN false ELSE true END FROM posts p
            LEFT OUTER JOIN post_replacements2 pr ON p.id = pr.post_id AND pr.status = 'pending'
          WHERE p.id IN (#{post_ids})
        SQL
        disapprovals_sql = <<-SQL
          SELECT post_id, array_agg(user_id) FROM post_disapprovals
          WHERE post_id IN (#{post_ids})
          GROUP BY post_id
        SQL

        # Run queries
        conn = ApplicationRecord.connection
        deletions      = conn.execute(deletion_sql)
        deleter_ids    = deletions.values.map {|p,did,dr| [p,did]}.to_h
        del_reasons    = deletions.values.map {|p,did,dr| [p,dr]}.to_h
        comment_counts = conn.execute(comments_sql).values.to_h
        pool_ids       = conn.execute(pools_sql).values.map(&array_parse).to_h
        set_ids        = conn.execute(sets_sql).values.map(&array_parse).to_h
        fave_ids       = conn.execute(faves_sql).values.map(&array_parse).to_h
        commenter_ids  = conn.execute(commenter_sql).values.map(&array_parse).to_h
        noter_ids      = conn.execute(noter_sql).values.map(&array_parse).to_h
        child_ids      = conn.execute(child_sql).values.map(&array_parse).to_h
        disapprovers   = conn.execute(disapprovals_sql).values.map(&array_parse).to_h
        notes          = Hash.new { |h,k| h[k] = [] }
        conn.execute(note_sql).values.each { |p,b| notes[p] << b }
        pending_replacements = conn.execute(pending_replacements_sql).values.to_h

        # Special handling for votes to do it with one query
        vote_ids = conn.execute(votes_sql).values.map do |pid, uids, scores|
          uids   = uids[1..-2].split(",").map(&:to_i)
          scores = scores[1..-2].split(",").map(&:to_i)
          [pid.to_i, uids.zip(scores)]
        end

        upvote_ids   = vote_ids.map { |pid, user| [pid, user.reject { |uid, s| s <= 0 }.map {|uid, _| uid}] }.to_h
        downvote_ids = vote_ids.map { |pid, user| [pid, user.reject { |uid, s| s >= 0 }.map {|uid, _| uid}] }.to_h

        empty = []
        batch.map! do |p|
          index_options = {
            comment_count: comment_counts[p.id] || 0,
            pools:         pool_ids[p.id]       || empty,
            sets:          set_ids[p.id]        || empty,
            faves:         fave_ids[p.id]       || empty,
            upvotes:       upvote_ids[p.id]     || empty,
            downvotes:     downvote_ids[p.id]   || empty,
            children:      child_ids[p.id]      || empty,
            commenters:    commenter_ids[p.id]  || empty,
            noters:        noter_ids[p.id]      || empty,
            notes:         notes[p.id]          || empty,
            deleter:       deleter_ids[p.id]    || empty,
            del_reason:    del_reasons[p.id]    || empty,
            disapprover:   disapprovers[p.id]   || empty,
            has_pending_replacements: pending_replacements[p.id],
            disa_count:   disapprovers[p.id].count || 0,
          }

          {
            index: {
              _id:  p.id,
              data: p.as_indexed_json(index_options),
            }
          }
        end

        client.bulk({
          index: index_name,
          body:  batch,
        })
      end
    end
  end

  def as_indexed_json(options = {})
    {
      created_at:        created_at,
      updated_at:        updated_at,
      commented_at:      last_commented_at,
      comment_bumped_at: last_comment_bumped_at,
      noted_at:          last_noted_at,
      id:                id,
      up_score:          up_score,
      down_score:        down_score,
      score:             score,
      fav_count:         fav_count,
      tag_count:         tag_count,
      change_seq:        change_seq,

      tag_count_general:   tag_count_general,
      tag_count_artist:    tag_count_artist,
      tag_count_character: tag_count_character,
      tag_count_copyright: tag_count_copyright,
      tag_count_meta:      tag_count_meta,
      tag_count_species:   tag_count_species,
      tag_count_invalid:   tag_count_invalid,
      tag_count_lore:      tag_count_lore,
      comment_count:       options[:comment_count] || comment_count,

      file_size:    file_size,
      parent:       parent_id,
      pools:        options[:pools]      || ::Pool.where("post_ids @> '{?}'", id).pluck(:id),
      sets:         options[:sets]       || ::PostSet.where("post_ids @> '{?}'", id).pluck(:id),
      commenters:   options[:commenters] || ::Comment.undeleted.where(post_id: id).pluck(:creator_id),
      noters:       options[:noters]     || ::Note.active.where(post_id: id).pluck(:creator_id),
      faves:        options[:faves]      || ::Favorite.where(post_id: id).pluck(:user_id),
      upvotes:      options[:upvotes]    || ::PostVote.where(post_id: id).where("score > 0").pluck(:user_id),
      downvotes:    options[:downvotes]  || ::PostVote.where(post_id: id).where("score < 0").pluck(:user_id),
      children:     options[:children]   || ::Post.where(parent_id: id).pluck(:id),
      notes:        options[:notes]      || ::Note.active.where(post_id: id).pluck(:body),
      uploader:     uploader_id,
      approver:     approver_id,
      disapprover:  options[:disapprover] || ::PostDisapproval.where(post_id: id).pluck(:user_id),
      dis_count:    options[:disa_count] || ::PostDisapproval.where(post_id: id).pluck(:user_id).size,
      deleter:      options[:deleter]    || ::PostFlag.where(post_id: id, is_resolved: false, is_deletion: true).order(id: :desc).first&.creator_id,
      del_reason:   options[:del_reason] || ::PostFlag.where(post_id: id, is_resolved: false, is_deletion: true).order(id: :desc).first&.reason&.downcase,
      width:        image_width,
      height:       image_height,
      mpixels:      image_width && image_height ? (image_width.to_f * image_height / 1_000_000).round(2) : 0.0,
      aspect_ratio: image_width && image_height ? (image_width.to_f / [image_height, 1].max).round(2) : 1.0,
      duration:     duration,

      tags:        tag_string.split(" "),
      md5:         md5,
      rating:      rating,
      file_ext:    file_ext,
      source:      source_array,
      description: description.present? ? description : nil,

      rating_locked:  is_rating_locked,
      note_locked:    is_note_locked,
      status_locked:  is_status_locked,
      flagged:        is_flagged,
      pending:        is_pending,
      deleted:        is_deleted,
      has_children:   has_children,
      has_pending_replacements: options.key?(:has_pending_replacements) ? options[:has_pending_replacements] : replacements.pending.any?
    }
  end
end
