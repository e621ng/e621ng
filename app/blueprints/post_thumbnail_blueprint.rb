# frozen_string_literal: true

# rubocop:disable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength

class PostThumbnailBlueprint < Blueprinter::Base
  identifier :id

  ### File Information ###
  field :md5
  field :file_ext
  field :image_width, name: :width
  field :image_height, name: :height
  field :file_size, name: :size

  field :preview_url do |post|
    post.visible? ? post.preview_file_url : nil
  end
  field :sample_url do |post|
    post.visible? ? post.sample_url : nil
  end
  field :file_url do |post|
    post.visible? ? post.file_url : nil
  end

  ### Post Metadata ###

  field :uploader_id
  field :uploader_name

  field :score
  field :fav_count
  field :is_favorited?, name: :is_favorited
  field :comment_count do |post|
    post.visible_comment_count(CurrentUser.user)
  end

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

  ### Tags, Rating, etc ###

  field :rating
  field :tag_string, name: :tags
end

# rubocop:enable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength
