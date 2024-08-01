# frozen_string_literal: true

class PostReplacement < ApplicationRecord
  self.table_name = 'post_replacements2'
  belongs_to :post
  belongs_to :creator, class_name: "User"
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :uploader_on_approve, class_name: "User", foreign_key: :uploader_id_on_approve, optional: true
  attr_accessor :replacement_file, :replacement_url, :tags, :is_backup, :as_pending, :is_destroyed_reupload

  validate :user_is_not_limited, on: :create
  validate :post_is_valid, on: :create
  validate :set_file_name, on: :create
  validate :fetch_source_file, on: :create
  validate :update_file_attributes, on: :create
  validate on: :create do |replacement|
    FileValidator.new(replacement, replacement_file.path).validate
    throw :abort if errors.any?
  end
  validate :no_pending_duplicates, on: :create
  validate :write_storage_file, on: :create
  validates :reason, length: { in: 5..150 }, presence: true, on: :create

  after_create -> { post.update_index }
  before_destroy :remove_files
  after_destroy -> { post.update_index }

  TAGS_TO_REMOVE_AFTER_ACCEPT = ["better_version_at_source"]
  HIGHLIGHTED_TAGS = ["better_version_at_source", "avoid_posting", "conditional_dnp"]

  def replacement_url_parsed
    return nil unless replacement_url =~ %r!\Ahttps?://!i
    Addressable::URI.heuristic_parse(replacement_url) rescue nil
  end

  def notify_reupload
    return unless is_destroyed_reupload
    if (destroyed_post = DestroyedPost.find_by(md5: md5))
      destroyed_post.notify_reupload(creator, replacement_post_id: post_id)
    end
  end

  module PostMethods
    def post_is_valid
      if post.is_deleted?
        self.errors.add(:post, "is deleted")
        return false
      end
    end
  end

  def no_pending_duplicates
    return true if is_backup

    if DestroyedPost.find_by(md5: md5)
      errors.add(:base, "That image had been deleted from our site, and cannot be re-uploaded")
      self.is_destroyed_reupload = true
      return
    end

    post = Post.where(md5: md5).first
    if post
      self.errors.add(:md5, "duplicate of existing post ##{post.id}")
      return false
    end
    replacements = PostReplacement.where(status: 'pending', md5: md5)
    replacements.each do |replacement|
      self.errors.add(:md5, "duplicate of pending replacement on post ##{replacement.post_id}")
    end
    replacements.size == 0
  end

  def user_is_not_limited
    return true if status == 'original'
    uploadable = creator.can_upload_with_reason
    if uploadable != true
      self.errors.add(:creator, User.upload_reason_string(uploadable))
      throw :abort
    end

    # Janitor bypass replacement limits
    return true if creator.is_janitor?

    if post.replacements.where(creator_id: creator.id).where('created_at > ?', 1.day.ago).count >= Danbooru.config.post_replacement_per_day_limit
      self.errors.add(:creator, 'has already suggested too many replacements for this post today')
      throw :abort
    end
    if post.replacements.where(creator_id: creator.id).count >= Danbooru.config.post_replacement_per_post_limit
      self.errors.add(:creator, 'has already suggested too many total replacements for this post')
      throw :abort
    end
    true
  end

  def source_list
    source.split("\n").uniq.reject(&:blank?)
  end

  module StorageMethods
    def remove_files
      PostEvent.add(post_id, CurrentUser.user, :replacement_deleted, { replacement_id: id, md5: md5, storage_id: storage_id})
      Danbooru.config.storage_manager.delete_replacement(self)
    end

    def fetch_source_file
      return if replacement_file.present?

      valid, reason = UploadWhitelist.is_whitelisted?(replacement_url_parsed)
      if !valid
        self.errors.add(:replacement_url, "is not whitelisted: #{reason}")
        throw :abort
      end

      download = Downloads::File.new(replacement_url_parsed)
      file = download.download!

      self.replacement_file = file
      self.source = "#{self.source}\n" + replacement_url
    rescue Downloads::File::Error
      self.errors.add(:replacement_url, "failed to fetch file")
      throw :abort
    end

    def update_file_attributes
      self.file_ext = file_header_to_file_ext(replacement_file.path)
      self.file_size = replacement_file.size
      self.md5 = Digest::MD5.file(replacement_file.path).hexdigest
      width, height = calculate_dimensions(replacement_file.path)
      self.image_width = width
      self.image_height = height
    end

    def set_file_name
      if replacement_file.present?
        self.file_name = replacement_file.try(:original_filename) || File.basename(replacement_file.path)
      else
        if replacement_url_parsed.blank? && replacement_url.present?
          self.errors.add(:replacement_url, "is invalid")
          throw :abort
        end
        if replacement_url_parsed.blank?
          self.errors.add(:base, "No file or replacement URL provided")
          throw :abort
        end
        self.file_name = replacement_url_parsed.basename
      end
    end

    def write_storage_file
      self.storage_id = SecureRandom.hex(16)
      Danbooru.config.storage_manager.store_replacement(replacement_file, self, :original)
      thumbnail_file = PostThumbnailer.generate_thumbnail(replacement_file, is_video? ? :video : :image)
      Danbooru.config.storage_manager.store_replacement(thumbnail_file, self, :preview)
    ensure
      thumbnail_file.try(:close!)
    end

    def replacement_file_path
      Danbooru.config.storage_manager.replacement_path(self, file_ext, :original)
    end

    def replacement_thumb_path
      Danbooru.config.storage_manager.replacement_path(self, file_ext, :preview)
    end

    def replacement_file_url
      Danbooru.config.storage_manager.replacement_url(self)
    end

    def replacement_thumb_url
      Danbooru.config.storage_manager.replacement_url(self, :preview)
    end
  end

  module ApiMethods
    def hidden_attributes
      super + %i[storage_id protected uploader_id_on_approve penalize_uploader_on_approve]
    end
  end

  module ProcessingMethods
    def approve!(penalize_current_uploader:)
      unless ["pending", "original"].include? status
        errors.add(:status, "must be pending or original to approve")
        return
      end

      processor = UploadService::Replacer.new(post: post, replacement: self)
      processor.process!(penalize_current_uploader: penalize_current_uploader)
      PostEvent.add(post.id, CurrentUser.user, :replacement_accepted, { replacement_id: id, old_md5: post.md5, new_md5: md5 })
      post.update_index
    end

    def toggle_penalize!
      if status != "approved"
        errors.add(:status, "must be approved to penalize")
        return
      end

      if penalize_uploader_on_approve
        UserStatus.for_user(uploader_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count - 1")
      else
        UserStatus.for_user(uploader_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count + 1")
      end
      update_attribute(:penalize_uploader_on_approve, !penalize_uploader_on_approve)
    end

    def promote!
      if status != "pending"
        errors.add(:status, "must be pending to promote")
        return
      end

      upload = transaction do
        processor = UploadService.new(new_upload_params)
        new_upload = processor.start!
        if new_upload.valid? && new_upload.post&.valid?
          update_attribute(:status, "promoted")
          PostEvent.add(new_upload.post.id, CurrentUser.user, :replacement_promoted, { source_post_id: post.id })
        end
        new_upload
      end
      post.update_index
      upload
    end

    def reject!
      if status != "pending"
        errors.add(:status, "must be pending to reject")
        return
      end

      PostEvent.add(post.id, CurrentUser.user, :replacement_rejected, { replacement_id: id })
      update_attribute(:status, 'rejected')
      UserStatus.for_user(creator_id).update_all("post_replacement_rejected_count = post_replacement_rejected_count + 1")
      post.update_index
    end
  end

  module PromotionMethods
    def new_upload_params
      {
          uploader_id: creator_id,
          uploader_ip_addr: creator_ip_addr,
          file: Danbooru.config.storage_manager.open(Danbooru.config.storage_manager.replacement_path(self, file_ext, :original)),
          tag_string: post.tag_string,
          rating: post.rating,
          source: "#{self.source}\n" + post.source,
          parent_id: post.id,
          description: post.description,
          locked_tags: post.locked_tags,
          replacement_id: self.id
      }
    end
  end

  concerning :Search do
    class_methods do
      def search(params)
        q = super

        q = q.attribute_exact_matches(:file_ext, params[:file_ext])
        q = q.attribute_exact_matches(:md5, params[:md5])
        q = q.attribute_exact_matches(:status, params[:status])

        q = q.where_user(:creator_id, :creator, params)
        q = q.where_user(:approver_id, :approver, params)
        q = q.where_user(:uploader_id_on_approve, %i[uploader_name_on_approve uploader_id_on_approve], params)

        if params[:post_id].present?
          q = q.where("post_id in (?)", params[:post_id].split(",").first(100).map(&:to_i))
        end

        q.order(Arel.sql("CASE status WHEN 'pending' THEN 0 ELSE 1 END ASC, id DESC"))
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

      def for_uploader_on_approve(id)
        where(uploader_id_on_approve: id.to_i)
      end

      def penalized
        where(penalize_uploader_on_approve: true)
      end

      def not_penalized
        where(penalize_uploader_on_approve: false)
      end

      def visible(user)
        return where('status != ?', 'rejected') if user.is_anonymous?
        return all if user.is_janitor?
        where('creator_id = ? or status != ?', user.id, 'rejected')
      end
    end
  end

  def original_file_visible_to?(user)
    user.is_janitor?
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end

  include ApiMethods
  include StorageMethods
  include FileMethods
  include ProcessingMethods
  include PromotionMethods
  include PostMethods
end
