# frozen_string_literal: true

class StaffFile < ApplicationRecord
  belongs_to_creator

  attr_accessor :file

  before_validation :initialize_storage_id, on: :create

  validates :file, presence: true, on: :create
  validate :set_file_properties
  validate :validate_file
  validates :storage_id, uniqueness: true

  module SearchMethods
    def search(params)
      q = super
      q = q.where_user(:creator_id, :creator, params)
      q = q.where_ilike(:original_filename, params[:original_filename]) if params[:original_filename].present?
      q = q.attribute_exact_matches(:file_ext, params[:file_ext]) if params[:file_ext].present?

      case params[:order]
      when "original_filename"
        q = q.order(Arel.sql("original_filename ASC"))
      when "time"
        q = q.order(created_at: :desc)
      else
        q = q.apply_basic_order(params)
      end
      q
    end
  end

  extend SearchMethods
  include FileMethods

  def initialize_storage_id
    self.storage_id ||= SecureRandom.hex(16)
  end

  def set_file_properties
    return if file.blank?

    self.original_filename = file.original_filename
    self.file_ext = normalize_ext(File.extname(file.original_filename.to_s).delete("."))
    self.md5 = Digest::MD5.file(file.path).hexdigest
    self.file_size = file.size
    self.title = original_filename if title.blank?
  end

  def validate_file
    return if file.blank?

    unless file_ext.in?(Danbooru.config.staff_file_allowed_extensions)
      errors.add(:file, "type '#{file_ext}' is not allowed")
      return
    end

    if file_size.to_i <= 16
      errors.add(:file, "is too small")
    elsif file_size > Danbooru.config.staff_file_max_size
      errors.add(:file, "is too large (maximum #{ApplicationController.helpers.number_to_human_size(Danbooru.config.staff_file_max_size)})")
    end

    # For media types we can confirm the bytes match the claimed extension via
    # magic-byte sniffing. Text/archive types are trusted by their filename,
    # since the shared sniffing helper only recognises image/video formats.
    if is_image? || is_video?
      detected = file_header_to_file_ext(file.path)
      errors.add(:file, "contents do not match its '#{file_ext}' extension") if detected != file_ext
    end
  end

  def can_delete?(user)
    user.is_admin? || creator_id == user.id
  end

  def file_url
    Danbooru.config.storage_manager.staff_file_url(self)
  end

  def file_path
    Danbooru.config.storage_manager.staff_file_path(self)
  end

  private

  def normalize_ext(ext)
    ext = ext.to_s.downcase
    ext == "jpeg" ? "jpg" : ext
  end
end
