# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Style/SymbolProc

class PostBlueprint < Blueprinter::Base
  identifier :id

  # TODO: For compatibility reasons, the following fields are in the same order as in the old API.
  # When we update the API to not include the object wrapper, we can reorder these fields more logically.

  fields :created_at, :updated_at

  field :file do |post|
    file_attributes = {
      width: post.image_width,
      height: post.image_height,
      ext: post.file_ext,
      size: post.file_size,
      md5: post.md5,
      url: nil,
    }
    if post.visible?
      file_attributes[:url] = post.file_url
    end
    file_attributes
  end

  field :preview do |post|
    preview_attributes = {
      width: post.preview_width,
      height: post.preview_height,
      url: nil,
      alt: nil,
    }
    if post.visible?
      preview_attributes[:url] = post.preview_file_url
      preview_attributes[:alt] = post.preview_file_url(:preview_webp)
    end
    preview_attributes
  end

  field :sample do |post|
    sample_attributes = {
      has: post.has_sample?,
      width: post.sample_width,
      height: post.sample_height,
      url: nil,
      alt: nil,
      alternates: post.video_sample_list,
    }
    if post.visible? && post.has_sample?
      sample_attributes[:url] = post.sample_url
      sample_attributes[:alt] = post.sample_url(:sample_webp)
    end
    sample_attributes
  end

  field :score do |post|
    {
      up: post.up_score,
      down: post.down_score,
      total: post.score,
    }
  end

  field :tags do |post|
    tags = {}
    TagCategory::REVERSE_MAPPING.each do |category_id, category_name|
      tags[category_name] = post.typed_tags(category_id)
    end
    tags
  end

  field :locked_tags do |post|
    post.locked_tags&.split || []
  end

  fields :change_seq

  field :flags do |post|
    {
      pending: post.is_pending,
      flagged: post.is_flagged,
      note_locked: post.is_note_locked,
      status_locked: post.is_status_locked,
      rating_locked: post.is_rating_locked,
      deleted: post.is_deleted,
    }
  end

  fields :rating, :fav_count

  field :sources do |post|
    post.source.split("\n")
  end

  field :pools do |post|
    post.pool_ids
  end

  field :relationships do |post|
    {
      parent_id: post.parent_id,
      has_children: post.has_children,
      has_active_children: post.has_active_children,
      children: post.children_ids&.split&.map(&:to_i) || [],
    }
  end

  fields :approver_id, :uploader_id, :uploader_name, :description

  field :comment_count do |post|
    post.visible_comment_count(CurrentUser.user)
  end

  field :is_favorited do |post|
    post.is_favorited?
  end

  field :has_notes do |post|
    post.has_notes?
  end

  field :duration do |post|
    post.duration&.to_f
  end
end

# rubocop:enable Style/SymbolProc
