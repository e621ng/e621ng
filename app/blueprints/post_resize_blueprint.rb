# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength

class PostResizeBlueprint < Blueprinter::Base
  identifier :id

  ### File Information ###
  field :meta do |post|
    {
      md5: post.md5,
      ext: post.file_ext,
      size: post.file_size,
      duration: post.duration&.to_f,

      has_sample: post.has_sample?,
    }
  end

  field :original do |post|
    {
      width: post.image_width,
      height: post.image_height,
      url: post.visible? ? post.file_url : nil,
    }
  end

  field :preview do |post|
    preview = post.preview_file_url_pair
    {
      width: post.preview_width,
      height: post.preview_height,
      jpg: post.visible? ? preview[1] : nil,
      webp: post.visible? ? preview[0] : nil,
    }
  end

  field :sample do |post|
    sample = post.sample_url_pair # falls back to original file if no sample is available
    {
      width: post.sample_width,
      height: post.sample_height,
      jpg: post.visible? ? sample[1] : nil,
      webp: post.visible? ? sample[0] : nil,
    }
  end

  field :video do |post|
    post.is_video? ? post.video_sample_list : {}
  end
end

# rubocop:enable Lint/RedundantCopDisableDirective, Style/SymbolProc, Metrics/BlockLength
