# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Style/SymbolProc, Metrics/BlockLength

class PostBlueprint < Blueprinter::Base
  identifier :id

  fields :created_at,
         :updated_at,
         :rating,
         :fav_count,
         :uploader_id,
         :uploader_name

  field :is_favorited do |post|
    post.is_favorited?
  end

  field :comment_count do |post|
    post.visible_comment_count(CurrentUser.user)
  end

  field :duration do |post|
    post.duration&.to_f
  end

  field :is_favorited do |post|
    post.is_favorited?
  end

  # Thumbnail View
  # The basic information needed to render a thumbnail that supports blacklisting
  view :thumbnail do
    field :md5
    field :file_ext
    field :tag_string, name: :tags
    field :image_width, name: :width
    field :image_height, name: :height
    field :file_size, name: :size
    field :score

    field :flags do |post|
      flags = []
      flags << "pending" if post.is_pending?
      flags << "flagged" if post.is_flagged?
      flags << "deleted" if post.is_deleted?
      flags.join(" ")
    end

    field :pools do |post|
      post.pool_ids.join(" ")
    end

    field :preview_file_url, name: :preview_url, if: ->(_field_name, post, _options) { post.visible? }
    field :sample_url, if: ->(_field_name, post, _options) { post.visible? }
    field :file_url, if: ->(_field_name, post, _options) { post.visible? }
  end

  # API Output
  # Complete information about a post, used exclusively for API output
  view :api do
    # File definitions
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

    # Tags
    field :tag_string, name: :tags
    field :locked_tags do |post|
      post.locked_tags&.split || []
    end

    # Miscellaneous
    field :score do |post|
      {
        up: post.up_score,
        down: post.down_score,
        total: post.score,
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

    field :pools do |post|
      post.pool_ids
    end

    field :relationships do |post|
      {
        parent_id: post.parent_id,
        children: post.children_ids&.split&.map(&:to_i) || [],
      }
    end

    field :has do |post|
      {
        parent: post.parent_id.present?,
        children: post.has_children,
        active_children: post.has_active_children,
        notes: post.has_notes?,
      }
    end

    field :sources do |post|
      post.source.split("\n")
    end

    fields :change_seq,
           :approver_id,
           :description
  end

  # Extended API Output
  # Includes tag categories, which requires additional queries
  view :extended do
    include_view :api

    field :tags do |post|
      tags = {}
      TagCategory::REVERSE_MAPPING.each do |category_id, category_name|
        tags[category_name] = post.typed_tags(category_id)
      end
      tags
    end
  end
end

# rubocop:enable Style/SymbolProc, Metrics/BlockLength
