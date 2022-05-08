class FileValidator
  attr_reader :record, :file_path

  def initialize(record, file_path)
    @record = record
    @file_path = file_path
  end

  def validate
    validate_file_ext
    validate_file_size
    validate_file_integrity
    validate_video_container_format
    validate_video_duration
    validate_resolution
  end

  def validate_file_integrity
    if record.is_image? && DanbooruImageResizer.is_corrupt?(file_path)
      record.errors.add(:file, "is corrupt")
    end
  end

  def validate_file_ext
    if Danbooru.config.max_file_sizes.keys.exclude? record.file_ext
      record.errors.add(:file_ext, "#{record.file_ext} is invalid (only JPEG, PNG, GIF, and WebM files are allowed")
      throw :abort
    end
  end

  def validate_file_size
    if record.file_size <= 16
      record.errors.add(:file_size, "is too small")
    end
    max_size = Danbooru.config.max_file_sizes.fetch(record.file_ext, 0)
    if record.file_size > max_size
      record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{max_size / (1024 * 1024)} MiB")
    end
    if record.is_apng && record.file_size > Danbooru.config.max_apng_file_size
      record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{Danbooru.config.max_apng_file_size / (1024*1024)} MiB")
    end
  end

  def validate_resolution
    resolution = record.image_width.to_i * record.image_height.to_i

    if resolution > Danbooru.config.max_image_resolution
      record.errors.add(:base, "image resolution is too large (resolution: #{(resolution / 1_000_000.0).round(1)} megapixels (#{record.image_width}x#{record.image_height}); max: #{Danbooru.config.max_image_resolution / 1_000_000} megapixels)")
    elsif record.image_width > Danbooru.config.max_image_width
      record.errors.add(:image_width, "is too large (width: #{record.image_width}; max width: #{Danbooru.config.max_image_width})")
    elsif record.image_height > Danbooru.config.max_image_height
      record.errors.add(:image_height, "is too large (height: #{record.image_height}; max height: #{Danbooru.config.max_image_height})")
    end
  end

  def validate_video_duration
    if record.is_video? && record.video.duration > Danbooru.config.max_video_duration
      record.errors.add(:base, "video must not be longer than #{Danbooru.config.max_video_duration} seconds")
    end
  end

  def validate_video_container_format
    if record.is_video?
      unless record.video.valid?
        record.errors.add(:base, "video isn't valid")
        return
      end
      valid_video_codec = %w[vp8 vp9 av1].include?(record.video.video_codec)
      valid_container = record.video.container == "matroska,webm"
      unless valid_video_codec && valid_container
        record.errors.add(:base, "video container/codec isn't valid for webm")
      end
    end
  end
end
