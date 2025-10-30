# frozen_string_literal: true

class PostSerializer < ActiveModel::Serializer
  def tags
    tags = {}
    TagCategory::REVERSE_MAPPING.each do |category_id, category_name|
      tags[category_name] = object.typed_tags(category_id)
    end
    tags
  end

  def file
    file_attributes = {
      width: object.image_width,
      height: object.image_height,
      ext: object.file_ext,
      size: object.file_size,
      md5: object.md5,
      url: nil,
    }
    if object.visible?
      file_attributes[:url] = object.file_url
    end
    file_attributes
  end

  def preview
    preview_attributes = {
      width: object.preview_width,
      height: object.preview_height,
      url: nil,
      alt: nil,
    }
    if object.visible?
      preview_attributes[:url] = object.preview_file_url
      preview_attributes[:alt] = object.preview_file_url(:preview_webp)
    end
    preview_attributes
  end

  def sample
    sample_attributes = {
      has: object.has_sample?,
      width: object.sample_width,
      height: object.sample_height,
      url: nil,
      alt: nil,
      alternates: object.video_sample_list,
    }
    if object.visible? && object.has_sample?
      sample_attributes[:url] = object.sample_url
      sample_attributes[:alt] = object.sample_url(:sample_webp)
    end
    sample_attributes
  end

  def score
    {
        up: object.up_score,
        down: object.down_score,
        total: object.score
    }
  end

  def flags
    {
        pending: object.is_pending,
        flagged: object.is_flagged,
        note_locked: object.is_note_locked,
        status_locked: object.is_status_locked,
        rating_locked: object.is_rating_locked,
        deleted: object.is_deleted
    }
  end

  def sources
    object.source.split("\n")
  end

  def pools
    object.pool_ids
  end

  def relationships
    {
        parent_id: object.parent_id,
        has_children: object.has_children,
        has_active_children: object.has_active_children,
        children: object.children_ids&.split&.map(&:to_i) || []
    }
  end

  def locked_tags
    object.locked_tags&.split || []
  end

  def is_favorited
    object.is_favorited?
  end

  def has_notes
    object.has_notes?
  end

  def duration
    object.duration ? object.duration.to_f : nil
  end

  def comment_count
    object.visible_comment_count(CurrentUser)
  end

  attributes :id, :created_at, :updated_at, :file, :preview, :sample, :score, :tags, :locked_tags, :change_seq, :flags,
             :rating, :fav_count, :sources, :pools, :relationships, :approver_id, :uploader_id, :uploader_name, :description,
             :comment_count, :is_favorited, :has_notes, :duration
end
