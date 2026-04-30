# frozen_string_literal: true

# rubocop:disable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength

class PostThumbnailBlueprint < Blueprinter::Base
  identifier :id

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

  field :tag_string, name: :tags
end

# rubocop:enable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength
