# frozen_string_literal: true

class FileValidator
  attr_reader :record, :file_path

  def initialize(record, file_path)
    @record = record
    @file_path = file_path
  end

  def validate(max_file_sizes: Danbooru.config.max_file_sizes, max_width: Danbooru.config.max_image_width, max_height: Danbooru.config.max_image_height)
    validate_file_ext(max_file_sizes)
    validate_file_size(max_file_sizes)
    validate_file_integrity
    if record.is_video?
      video = record.video(file_path)
      validate_container_format(video)
      validate_duration(video)
      validate_colorspace(video)
      validate_sar(video)
    end
    validate_resolution(max_width, max_height)
  end

  def validate_file_integrity
    if record.is_image? && record.is_corrupt?(file_path)
      record.errors.add(:file, "is corrupt")
    end
  end

  def validate_file_ext(max_file_sizes)
    if max_file_sizes.keys.exclude? record.file_ext
      record.errors.add(:file_ext, "#{record.file_ext} is invalid (only #{max_file_sizes.keys.to_sentence} files are allowed)")
      throw :abort
    end
  end

  def validate_file_size(max_file_sizes)
    if record.file_size <= 16
      record.errors.add(:file_size, "is too small")
    end
    max_size = max_file_sizes.fetch(record.file_ext, 0)
    if record.file_size > max_size
      record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{ApplicationController.helpers.number_to_human_size(max_size)}")
    end
    if record.is_animated_png?(file_path) && record.file_size > Danbooru.config.max_apng_file_size
      record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{ApplicationController.helpers.number_to_human_size(Danbooru.config.max_apng_file_size)}")
    end
  end

  def validate_resolution(max_width, max_height)
    resolution = record.image_width.to_i * record.image_height.to_i

    if resolution > Danbooru.config.max_image_resolution
      record.errors.add(:base, "image resolution is too large (resolution: #{(resolution / 1_000_000.0).round(1)} megapixels (#{record.image_width}x#{record.image_height}); max: #{Danbooru.config.max_image_resolution / 1_000_000} megapixels)")
    elsif record.image_width > max_width
      record.errors.add(:image_width, "is too large (width: #{record.image_width}; max width: #{max_width})")
    elsif record.image_height > max_height
      record.errors.add(:image_height, "is too large (height: #{record.image_height}; max height: #{max_height})")
    end
  end

  def validate_duration(video)
    if video.duration > Danbooru.config.max_video_duration
      record.errors.add(:base, "video must not be longer than #{Danbooru.config.max_video_duration} seconds")
    end
  end

  def validate_container_format(video)
    unless video.valid?
      record.errors.add(:base, "video isn't valid")
      return
    end
    valid_video_codec = %w[vp8 vp9 av1].include?(video.video_codec)
    valid_container = video.container == "matroska,webm"
    unless valid_video_codec && valid_container
      record.errors.add(:base, "video container/codec isn't valid for webm")
    end
  end

  def validate_colorspace(video)
    record.errors.add(:base, "video colorspace must be yuv420p, was #{video.colorspace}") unless video.colorspace == "yuv420p"
  end

  def validate_sar(video)
    record.errors.add(:base, "video is anamorphic (#{video.sar})") unless video.sar == "1:1"
  end
end
