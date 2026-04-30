# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength

class PostBlueprint < Blueprinter::Base
  identifier :id
  # Fields are displayed in the same order that they are defined

  field :created_at
  field :updated_at
  field :change_seq

  ### File Information ###

  field :files do |post|
    output = {}

    output[:meta] = {
      md5: post.md5,
      ext: post.file_ext,
      size: post.file_size,
      duration: post.duration&.to_f,

      has_sample: post.has_sample?,
    }

    output[:original] = {
      width: post.image_width,
      height: post.image_height,
      url: nil,
    }

    output[:preview] = {
      width: post.preview_width,
      height: post.preview_height,
      jpg: nil,
      webp: nil,
    }

    output[:sample] = {
      width: post.sample_width,
      height: post.sample_height,
      jpg: nil,
      webp: nil,
    }

    if post.visible?
      output[:original][:url] = post.file_url

      preview = post.preview_file_url_pair
      output[:preview][:webp] = preview[0]
      output[:preview][:jpg] = preview[1]

      sample = post.sample_url_pair # falls back to original file if no sample is available
      output[:sample][:webp] = sample[0]
      output[:sample][:jpg] = sample[1]
    end

    if post.is_video?
      output[:video] = post.video_sample_list
    end

    output
  end

  ### Post Metadata ###

  field :uploader_id
  field :uploader_name
  field :approver_id

  field :stats do |post|
    {
      score: {
        up: post.up_score,
        down: post.down_score,
        total: post.score,
      },
      fav_count: post.fav_count,
      is_favorited: post.is_favorited?,
      comment_count: post.visible_comment_count(CurrentUser.user),
    }
  end

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

  field :has do |post|
    {
      parent: post.parent_id.present?,
      children: post.has_children,
      active_children: post.has_active_children,
      notes: post.has_notes?,
      sample: post.has_sample?,
    }
  end

  field :relationships do |post|
    {
      parent_id: post.parent_id,
      children: post.children_ids&.split&.map(&:to_i) || [],
    }
  end

  field :pools do |post|
    post.pool_ids
  end

  ### Tags, Rating, Sources, and Description ###

  field :rating
  field :locked_tags do |post|
    post.locked_tags&.split || []
  end

  field :sources do |post|
    post.source.split("\n")
  end

  field :description

  ### Views ###

  # Basic API Output: no categories, better performance
  view :basic do
    field :tags do |post|
      post.tag_string.split
    end
  end

  # Extended API Output: includes tag categories
  view :extended do
    field :tags do |post|
      tags = {}
      TagCategory::REVERSE_MAPPING.each do |category_id, category_name|
        tags[category_name] = post.typed_tags(category_id)
      end
      tags
    end
  end
end

# rubocop:enable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength
