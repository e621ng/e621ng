# frozen_string_literal: true

class PostReplacement < ApplicationRecord
  self.table_name = "post_replacements2"
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
  validate :reason, on: :create do
    next if status == "original"

    # ensure reason is not blank or disallowed
    if reason.to_s.strip.squeeze(" ").casecmp("Backup of original file") == 0
      errors.add(:base, "You cannot use 'Backup of original file' as a reason.")
    end
    if reason.to_s.strip.blank?
      errors.add(:base, "You must provide a reason.")
    end
  end
  validate on: :create do |replacement|
    FileValidator.new(replacement, replacement_file.path).validate
    throw :abort if errors.any?
  end
  validate :no_pending_duplicates, on: :create
  validate :write_storage_file, on: :create
  validates :reason, length: { in: 5..150 }, presence: true, on: :create

  before_create :create_original_backup
  before_create :set_previous_uploader
  after_create -> { post.update_index }
  before_destroy :remove_files
  after_destroy -> { post.update_index }

  TAGS_TO_REMOVE_AFTER_ACCEPT = ["better_version_at_source"].freeze
  HIGHLIGHTED_TAGS = %w[better_version_at_source avoid_posting conditional_dnp].freeze

  def replacement_url_parsed
    return nil unless replacement_url =~ %r{\Ahttps?://}i
    begin
      Addressable::URI.heuristic_parse(replacement_url)
    rescue StandardError
      nil
    end
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
        errors.add(:post, "is deleted")
        false
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
      errors.add(:md5, "duplicate of existing post ##{post.id}")
      return false
    end
    replacements = PostReplacement.where(status: "pending", md5: md5)
    replacements.each do |replacement|
      errors.add(:md5, "duplicate of pending replacement on post ##{replacement.post_id}")
    end
    replacements.empty?
  end

  def sequence_number
    return 0 if status == "original"
    siblings = PostReplacement.where(post_id: post_id).where.not(status: "original").ids
    1 + siblings.index(id)
  end

  def user_is_not_limited
    return true if status == "original"
    uploadable = creator.can_upload_with_reason
    if uploadable != true
      errors.add(:creator, User.upload_reason_string(uploadable))
      throw :abort
    end

    # Janitor bypass replacement limits
    return true if creator.is_janitor?

    if post.replacements.where(creator_id: creator.id).where("created_at > ?", 1.day.ago).count >= Danbooru.config.post_replacement_per_day_limit
      errors.add(:creator, "has already suggested too many replacements for this post today")
      throw :abort
    end
    if post.replacements.where(creator_id: creator.id, status: "pending").count >= Danbooru.config.post_replacement_per_post_limit
      errors.add(:creator, "already has too many pending replacements for this post")
      throw :abort
    end
    true
  end

  def source_list
    source.split("\n").uniq.compact_blank
  end

  module StorageMethods
    def remove_files
      PostEvent.add(post_id, CurrentUser.user, :replacement_deleted, { replacement_id: id, md5: md5, storage_id: storage_id})
      Danbooru.config.storage_manager.delete_replacement(self)
    end

    def fetch_source_file
      return if replacement_file.present?

      valid, reason = UploadWhitelist.is_whitelisted?(replacement_url_parsed)
      unless valid
        errors.add(:replacement_url, "is not whitelisted: #{reason}")
        throw :abort
      end

      download = Downloads::File.new(replacement_url_parsed)
      file = download.download!

      self.replacement_file = file
      self.source = "#{source}\n" + replacement_url
    rescue Downloads::File::Error
      errors.add(:replacement_url, "failed to fetch file")
      throw :abort
    end

    def update_file_attributes
      self.file_ext = file_header_to_file_ext(replacement_file.path)
      self.file_size = replacement_file.size
      self.md5 = Digest::MD5.file(replacement_file.path).hexdigest
      width, height = calculate_dimensions(replacement_file.path)
      self.image_width = width
      self.image_height = height
      # self.duration = video_duration(replacement_file.path)
    end

    def set_file_name
      if replacement_file.present?
        self.file_name = replacement_file.try(:original_filename) || File.basename(replacement_file.path)
      else
        if replacement_url_parsed.blank? && replacement_url.present?
          errors.add(:replacement_url, "is invalid")
          throw :abort
        end
        if replacement_url_parsed.blank?
          errors.add(:base, "No file or replacement URL provided")
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
      if is_current? || is_promoted?
        errors.add(:status, "version is already active")
        return
      end

      if is_rejected? # We need to undo the rejection count
        UserStatus.for_user(creator_id).update_all("post_replacement_rejected_count = post_replacement_rejected_count - 1")
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

      # Record the change in a PostEvent
      PostEvent.add(post.id, CurrentUser.user, :replacement_penalty_changed, { replacement_id: id, penalize: !penalize_uploader_on_approve })

      if penalize_uploader_on_approve
        UserStatus.for_user(uploader_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count - 1")
      else
        UserStatus.for_user(uploader_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count + 1")
      end
      update_attribute(:penalize_uploader_on_approve, !penalize_uploader_on_approve)
    end

    def promote!
      unless %w[rejected pending].include?(status) || (is_approved? && !is_current?)
        errors.add(:status, "must be pending to promote")
        return
      end

      upload = transaction do
        processor = UploadService.new(new_upload_params)
        new_upload = processor.start!
        if new_upload.valid? && new_upload.post&.valid?
          update_attribute(:status, "promoted")
          update_attribute(:approver_id, CurrentUser.user.id)
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
      update_attribute(:status, "rejected")
      update_attribute(:approver_id, CurrentUser.user.id)
      UserStatus.for_user(creator_id).update_all("post_replacement_rejected_count = post_replacement_rejected_count + 1")
      post.update_index
    end

    def create_original_backup
      return if is_backup || post.replacements.where(status: "original").exists?

      backup = post.replacements.new(
        creator_id: post.uploader_id,
        creator_ip_addr: post.uploader_ip_addr,
        status: "original",
        image_width: post.image_width,
        image_height: post.image_height,
        file_ext: post.file_ext,
        file_size: post.file_size,
        md5: post.md5,
        file_name: "#{post.md5}.#{post.file_ext}",
        source: post.source,
        reason: "Backup of original file",
        is_backup: true,
        approver_id: post.approver_id,
      )

      begin
        backup.replacement_file = Danbooru.config.storage_manager.open(
          Danbooru.config.storage_manager.file_path(post, post.file_ext, :original),
        )
      rescue StandardError => e
        raise ProcessingError, "Failed to create backup: #{e.message}"
      end

      unless backup.save
        errors.add(:base, "Failed to create backup: #{backup.errors.full_messages.to_sentence}")
        throw :abort
      end
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
        source: "#{source}\n" + post.source,
        parent_id: post.id,
        description: post.description,
        locked_tags: post.locked_tags,
        replacement_id: id,
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

        if params[:reason].present?
          q = q.attribute_matches(:reason, params[:reason])
        end

        if params[:penalized].to_s.truthy?
          q = q.where("penalize_uploader_on_approve IS true")
        elsif params[:penalized].to_s.falsy?
          q = q.where("penalize_uploader_on_approve IS false")
        end

        if params[:source].present?
          url_query = params[:source].strip
          url_query = "*#{url_query}*" if params[:source].exclude?("*")
          # prefer 'ilike %#{url_query}%', but it doesn't work with `where_ilike`?
          q = q.where_ilike(:source, url_query)
        end

        if params[:file_name].present?
          q = q.attribute_matches(:file_name, params[:file_name])
        end

        direction = params[:order] == "id_asc" ? "ASC" : "DESC"

        q.order(Arel.sql("
          CASE status
            WHEN 'original' THEN 0
            ELSE #{table_name}.id
          END #{direction}
        "))
      end

      def pending
        where(status: "pending")
      end

      def rejected
        where(status: "rejected")
      end

      def approved
        where(status: "approved")
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
        return where.not(status: "rejected") if user.is_anonymous?
        return all if user.is_janitor?
        where("creator_id = ? or status != ?", user.id, "rejected")
      end
    end
  end

  def set_previous_uploader
    return if uploader_id_on_approve.present?
    uploader = post.uploader_id
    if uploader == creator_id
      self.penalize_uploader_on_approve = false
    end
    self.uploader_on_approve = User.find_by(id: uploader)
  end

  def original_file_visible_to?(user)
    user.is_janitor?
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end

  def is_current?
    md5 == post.md5
  end

  def is_pending?
    status == "pending"
  end

  def is_backup?
    status == "original"
  end

  def is_approved?
    status == "approved"
  end

  def is_rejected?
    status == "rejected"
  end

  def is_promoted?
    status == "promoted"
  end

  def is_retired?
    status == "approved" && !is_current?
  end

  def promoted_id
    return nil unless is_promoted?
    if post.has_children?
      id = post.children.where(md5: md5)&.first&.id
    end
    return id unless id.nil?
    Post.find_by(md5: md5)&.id
  end

  include ApiMethods
  include StorageMethods
  include FileMethods
  include ProcessingMethods
  include PromotionMethods
  include PostMethods
end
