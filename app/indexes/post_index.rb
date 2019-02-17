# frozen_string_literal: true

module PostIndex
  def self.included(base)
    base.settings index: { number_of_shards: 5, number_of_replicas: 1 } do
      mappings dynamic: false, _all: { enabled: false } do
        indexes :created_at,    type: 'date'
        indexes :updated_at,    type: 'date'
        indexes :id,            type: 'integer'
        indexes :up_score,      type: 'integer'
        indexes :down_score,    type: 'integer'
        indexes :score,         type: 'integer'
        indexes :fav_count,     type: 'integer'
        indexes :tag_count,     type: 'integer'

        indexes :tag_count_general,   type: 'integer'
        indexes :tag_count_artist,    type: 'integer'
        indexes :tag_count_character, type: 'integer'
        indexes :tag_count_copyright, type: 'integer'
        indexes :tag_count_meta,      type: 'integer'
        indexes :tag_count_species,   type: 'integer'
        indexes :comment_count,       type: 'integer'

        indexes :file_size,     type: 'integer'
        indexes :pixiv_id,      type: 'integer'
        indexes :parent_id,     type: 'integer'
        indexes :child_ids,     type: 'integer'
        indexes :pool_ids,      type: 'integer'
        indexes :set_ids,       type: 'integer'
        indexes :width,         type: 'integer'
        indexes :height,        type: 'integer'
        indexes :aspect_ratio,  type: 'float'

        indexes :tags,          type: 'keyword'
        indexes :pools,         type: 'keyword'
        indexes :sets,          type: 'keyword'
        indexes :md5,           type: 'keyword'
        indexes :rating,        type: 'keyword'
        indexes :file_ext,      type: 'keyword'
        indexes :source,        type: 'keyword'
        indexes :faves,         type: 'keyword'
        indexes :upvotes,       type: 'keyword'
        indexes :downvotes,     type: 'keyword'
        indexes :approver,      type: 'keyword'
        indexes :deleter,       type: 'keyword'
        indexes :uploader,      type: 'keyword'

        indexes :rating_locked,   type: 'boolean'
        indexes :note_locked,     type: 'boolean'
        indexes :hide_anon,       type: 'boolean'
        indexes :hide_google,     type: 'boolean'
        indexes :flagged,         type: 'boolean'
        indexes :pending,         type: 'boolean'
        indexes :deleted,         type: 'boolean'
        indexes :has_description, type: 'boolean'

        indexes :description, type: 'text', analyzer: 'snowball'
      end
    end
  end

  def as_indexed_json(options = {})
    {
      created_at: created_at,
      updated_at: updated_at,
      id: id,
      up_score: up_score,
      down_score: down_score,
      score: score,
      fav_count: fav_count,
      tag_count: tag_count,

      tag_count_general: tag_count_general,
      tag_count_artist: tag_count_artist,
      tag_count_character: tag_count_character,
      tag_count_copyright: tag_count_copyright,
      tag_count_meta: tag_count_meta,
      # tag_count_species: tag_count_species,
      # comment_count: comment_count,

      file_size: file_size,
      pixiv_id: pixiv_id,
      parent_id: parent_id,
      # child_ids: child_ids,
      # pool_ids: pool_ids,
      # set_ids: set_ids,
      width: image_width,
      height: image_height,
      aspect_ratio: image_width.to_f / [image_height, 1].max,

      tags: tag_string.split(' '),
      pools: pool_string.split(' '),
      # sets: set_string.split(' '),
      md5: md5,
      rating: rating,
      file_ext: file_ext,
      source: source.presence,
      faves: fav_string.split(' '),
      # upvotes: upvotes,
      # downvotes: downvotes,
      approver: approver&.name,
      # deleter: deleter&.name,
      uploader: uploader&.name,

      rating_locked: is_rating_locked,
      note_locked: is_note_locked,
      # hide_anon: hide_anon,
      # hide_google: hide_google,
      flagged: is_flagged,
      pending: is_pending,
      deleted: is_deleted,
      # has_description: description.present?,

      # description: description.presence,
    }
  end
end
