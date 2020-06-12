require "tmpdir"

class Upload < ApplicationRecord
  class Error < Exception ; end

  class FileValidator < ActiveModel::Validator
    def validate(record)
      validate_file_ext(record)
      validate_md5_uniqueness(record)
      validate_file_size(record)
      validate_file_integrity(record)
      validate_video_container_format(record)
      validate_video_duration(record)
      validate_resolution(record)
    end

    def validate_file_integrity(record)
      if record.file_ext.in?(["jpg", "jpeg", "gif", "png"]) && DanbooruImageResizer.is_corrupt?(record.file.path)
        record.errors[:file] << "File is corrupt"
      end
    end

    def validate_file_ext(record)
      if record.file_ext == "bin"
        record.errors.add(:file_ext, "is invalid (only JPEG, PNG, GIF, and WebM files are allowed")
      end
    end

    def validate_file_size(record)
      if record.file_size <= 16
        record.errors[:file_size] << "is too small"
      end
      max_size = Danbooru.config.max_file_sizes.fetch(record.file_ext, 0)
      if record.file_size > max_size
        record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{max_size / (1024*1024)} MiB")
      end
      if record.is_apng && record.file_size > Danbooru.config.max_apng_file_size
        record.errors.add(:file_size, "is too large. Maximum allowed for this file type is #{Danbooru.config.max_apng_file_size / (1024*1024)} MiB")
      end
    end

    def validate_md5_uniqueness(record)
      if record.md5.nil?
        return
      end

      replacements = PostReplacement.pending.where(md5: record.md5)
      replacements = replacements.where('id != ?', record.replacement_id) if record.replacement_id

      if !record.replaced_post && replacements.size > 0
        replacements.each do |rep|
          record.errors.add(:md5) << "duplicate of pending replacement on post ##{rep.post_id}"
        end
        return
      end

      md5_post = Post.find_by_md5(record.md5)

      if md5_post.nil?
        return
      end

      if record.replaced_post && record.replaced_post == md5_post
        return
      end

      record.errors.add(:md5, "duplicate: #{md5_post.id}")
    end

    def validate_resolution(record)
      resolution = record.image_width.to_i * record.image_height.to_i

      if resolution > Danbooru.config.max_image_resolution
        record.errors.add(:base, "image resolution is too large (resolution: #{(resolution / 1_000_000.0).round(1)} megapixels (#{record.image_width}x#{record.image_height}); max: #{Danbooru.config.max_image_resolution / 1_000_000} megapixels)")
      elsif record.image_width > Danbooru.config.max_image_width
        record.errors.add(:image_width, "is too large (width: #{record.image_width}; max width: #{Danbooru.config.max_image_width})")
      elsif record.image_height > Danbooru.config.max_image_height
        record.errors.add(:image_height, "is too large (height: #{record.image_height}; max height: #{Danbooru.config.max_image_height})")
      end
    end

    def validate_video_duration(record)
      if record.is_video? && record.video.duration > Danbooru.config.max_video_duration
        record.errors.add(:base, "video must not be longer than #{Danbooru.config.max_video_duration} seconds")
      end
    end

    def validate_video_container_format(record)
      if record.is_video?
        unless record.video.valid?
          record.errors.add(:base, "video isn't valid")
          return
        end
        valid_video_codec = %w{vp8 vp9 av1}.include?(record.video.video_codec)
        valid_container = record.video.container == "matroska,webm"
        unless valid_video_codec && valid_container
          record.errors.add(:base, "video container/codec isn't valid for webm")
        end
      end
    end
  end


  attr_accessor :as_pending, :replaced_post, :file, :direct_url, :is_apng, :original_post_id, :locked_tags, :locked_rating, :replacement_id
  belongs_to :uploader, :class_name => "User"
  belongs_to :post, optional: true

  before_validation :initialize_attributes, on: :create
  before_validation :assign_rating_from_tags
  before_validation :fixup_source, on: :create
  validate :uploader_is_not_limited, on: :create
  validate :direct_url_is_whitelisted, on: :create
  # validates :source, format: { with: /\Ahttps?/ }, if: ->(record) {record.file.blank?}, on: :create
  validates :rating, inclusion: { in: %w(q e s) }, allow_nil: false
  validates :md5, confirmation: true, if: -> (rec) { rec.md5_confirmation.present? }
  validates_with FileValidator, on: :file
  serialize :context, JSON

  def initialize_attributes
    self.server = Danbooru.config.server_host
  end

  module FileMethods
    def is_image?
      %w(jpg jpeg gif png).include?(file_ext)
    end

    def is_flash?
      %w(swf).include?(file_ext)
    end

    def is_video?
      %w(webm).include?(file_ext)
    end

    def is_ugoira?
      %w(zip).include?(file_ext)
    end
  end

  module StatusMethods
    def is_pending?
      status == "pending"
    end

    def is_processing?
      status == "processing"
    end

    def is_completed?
      status == "completed"
    end

    def is_preprocessed?
      status == "preprocessed"
    end

    def is_preprocessing?
      status == "preprocessing"
    end

    def is_duplicate?
      status.match?(/duplicate: \d+/)
    end

    def is_errored?
      status.match?(/error:/)
    end

    def sanitized_status
      if is_errored?
        status.sub(/DETAIL:.+/m, "...")
      else
        status
      end
    end

    def duplicate_post_id
      @duplicate_post_id ||= status[/duplicate: (\d+)/, 1]
    end
  end

  module DirectURLMethods
    def direct_url=(source)
      source = source.unicode_normalize(:nfc)

      # percent encode unicode characters in urls
      if source =~ %r!\Ahttps?://!i
        source = Addressable::URI.normalized_encode(source) rescue source
      end

      super(source)
    end

    def direct_url_parsed
      return nil unless direct_url =~ %r!\Ahttps?://!i
      Addressable::URI.heuristic_parse(direct_url) rescue nil
    end
  end

  module UploaderMethods
    def uploader_name
      User.id_to_name(uploader_id)
    end
  end

  module VideoMethods
    def video
      @video ||= FFMPEG::Movie.new(file.path)
    end

    def video_duration
      return video.duration if is_video? && video.duration
      nil
    end
  end

  module SearchMethods
    def uploaded_by(user_id)
      where("uploader_id = ?", user_id)
    end

    def pending
      where(:status => "pending")
    end

    def post_tags_match(query)
      where(post_id: PostQueryBuilder.new(query).build.reorder(""))
    end

    def search(params)
      q = super

      if params[:uploader_id].present?
        q = q.attribute_matches(:uploader_id, params[:uploader_id])
      end

      if params[:uploader_name].present?
        q = q.where(uploader_id: User.name_to_id(params[:uploader_name]))
      end

      if params[:source].present?
        q = q.where(source: params[:source])
      end

      if params[:source_matches].present?
        q = q.where("uploads.source LIKE ? ESCAPE E'\\\\'", params[:source_matches].to_escaped_for_sql_like)
      end

      if params[:rating].present?
        q = q.where(rating: params[:rating])
      end

      if params[:parent_id].present?
        q = q.attribute_matches(:rating, params[:parent_id])
      end

      if params[:post_id].present?
        q = q.attribute_matches(:post_id, params[:post_id])
      end

      if params[:has_post].to_s.truthy?
        q = q.where.not(post_id: nil)
      elsif params[:has_post].to_s.falsy?
        q = q.where(post_id: nil)
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:status].present?
        q = q.where("uploads.status LIKE ? ESCAPE E'\\\\'", params[:status].to_escaped_for_sql_like)
      end

      if params[:backtrace].present?
        q = q.where("uploads.backtrace LIKE ? ESCAPE E'\\\\'", params[:backtrace].to_escaped_for_sql_like)
      end

      if params[:tag_string].present?
        q = q.where("uploads.tag_string LIKE ? ESCAPE E'\\\\'", params[:tag_string].to_escaped_for_sql_like)
      end

      if params[:server].present?
        q = q.where(server: params[:server])
      end

      q.apply_default_order(params)
    end
  end

  module ApiMethods
    def method_attributes
      super + [:uploader_name]
    end
  end

  include FileMethods
  include StatusMethods
  include UploaderMethods
  include VideoMethods
  extend SearchMethods
  include ApiMethods
  include DirectURLMethods

  def uploader_is_not_limited
    uploadable = uploader.can_upload_with_reason
    if uploadable != true
      self.errors.add(:uploader, User.upload_reason_string(uploadable))
      return false
    end
    true
  end

  def direct_url_is_whitelisted
    return true if direct_url_parsed.nil?
    valid, reason = UploadWhitelist.is_whitelisted?(direct_url_parsed)
    if !valid
      self.errors.add(:source, "is not whitelisted: #{reason}")
      return false
    end
    true
  end

  def assign_rating_from_tags
    if rating = Tag.has_metatag?(tag_string, :rating)
      self.rating = rating.downcase.first
    end
  end

  def fixup_source
    if direct_url_parsed.present?
      canonical = Sources::Strategies.find(direct_url_parsed, referer_url).canonical_url
      self.source += "\n#{canonical}" if canonical
    end
  end

  def presenter
    @presenter ||= UploadPresenter.new(self)
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end
end
