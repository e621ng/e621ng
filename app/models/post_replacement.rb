class PostReplacement < ApplicationRecord
  belongs_to :post
  belongs_to :creator, class_name: "User"
  attr_accessor :replacement_file, :replacement_url, :final_source, :tags

  validate :set_file_name, on: :create
  validate :fetch_source_file, on: :create
  validate :update_file_attributes, on: :create
  validate :write_storage_file, on: :create
  validate :user_is_not_limited, on: :create

  before_destroy :remove_files

  def replacement_url_parsed
    return nil unless replacement_url =~ %r!\Ahttps?://!i
    Addressable::URI.heuristic_parse(replacement_url) rescue nil
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

  def user_is_not_limited
    return true if status == 'original'
    replaceable = creator.can_replace_post_with_reason
    if replaceable != true
      self.errors.add(:creator, User.throttle_reason(replaceable))
      return false
    end
    uploadable = creator.can_upload_with_reason
    if uploadable != true
      self.errors.add(:creator, User.upload_reason_string(uploadable))
      return false
    end
    true
  end

  module StorageMethods
    def remove_files
      ModAction.log(:post_replacement_delete, {id: id, post_id: post_id, md5: md5, storage_id: storage_id})
      Danbooru.config.storage_manager.delete_replacement(self)
    end

    def fetch_source_file
      return if replacement_file.present?

      download = Downloads::File.new(replacement_url_parsed, "")
      file, strategy = download.download!

      self.replacement_file = file
    end

    def update_file_attributes
      self.file_ext = UploadService::Utils.file_header_to_file_ext(replacement_file)
      self.file_size = replacement_file.size
      self.md5 = Digest::MD5.file(replacement_file.path).hexdigest

      UploadService::Utils.calculate_dimensions(self, replacement_file) do |width, height|
        self.image_width = width
        self.image_height = height
      end
    end

    def set_file_name
      if replacement_file.present?
        self.file_name = replacement_file.try(:original_filename) || File.basename(replacement_file.path)
      else
        raise RuntimeError, "No file or source URL provided" if replacement_url_parsed.blank?
        self.file_name = replacement_url_parsed.basename
      end
    end

    def write_storage_file
      self.storage_id = SecureRandom.hex(16)
      Danbooru.config.storage_manager.store_replacement(replacement_file, self, :original)
      thumbnail_file = PostThumbnailer.generate_thumbnail(replacement_file, is_video? ? :video : :image)
      Danbooru.config.storage_manager.store_replacement(thumbnail_file, self, :thumb)
    ensure
      thumbnail_file.try(:close!)
    end

    def replacement_file_url
      Danbooru.config.storage_manager.replacement_url(self)
    end

    def replacement_thumb_url
      Danbooru.config.storage_manager.replacement_url(self, :thumb)
    end
  end

  module ApiMethods
    def hidden_attributes
      super + [:storage_id]
    end
  end

  module ProcessingMethods
    def approve!
      transaction do
        processor = UploadService::Replacer.new(post: post, replacement: self)
        processor.process!
      end
    end

    def reject!
      update_attribute(:status, 'rejected')
    end
  end

  concerning :Search do
    class_methods do
      def search(params = {})
        q = super

        q = q.attribute_matches(:file_ext, params[:file_ext])
        q = q.attribute_matches(:md5, params[:md5])

        if params[:creator_id].present?
          q = q.where(creator_id: params[:creator_id].split(",").map(&:to_i))
        end

        if params[:creator_name].present?
          q = q.where(creator_id: User.name_to_id(params[:creator_name]))
        end

        if params[:post_id].present?
          q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
        end

        q.apply_default_order(params)
      end

      def pending
        where(status: 'pending')
      end

      def rejected
        where(status: 'rejected')
      end

      def approved
        where(status: 'approved')
      end

      def for_user(id)
        where(creator_id: id.to_i)
      end
    end
  end

  def file_visible_to?(user)
    true if user.is_janitor? || creator_id == user.id && status == 'pending'
    false
  end

  include ApiMethods
  include StorageMethods
  include FileMethods
  include ProcessingMethods

end
