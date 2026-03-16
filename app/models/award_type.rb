# frozen_string_literal: true

class AwardType < ApplicationRecord
  include FileMethods

  belongs_to_creator
  has_many :awards, dependent: :destroy

  attr_accessor :icon_file

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validate :validate_icon_file_is_png, if: :icon_file

  before_save :set_has_icon, if: :icon_file
  after_save_commit :write_icon_file
  after_destroy_commit :remove_icon_file

  module SearchMethods
    def search(params)
      q = super

      q = q.attribute_matches(:name, params[:name_matches]) if params[:name_matches].present?
      q = q.where_user(:creator_id, :creator, params)

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def icon_url
    if has_icon?
      Danbooru.config.storage_manager.award_type_icon_url(id)
    else
      "/images/download-preview.png"
    end
  end

  private

  def validate_icon_file_is_png
    ext = file_header_to_file_ext(icon_file.path)
    errors.add(:icon_file, "must be a PNG file") unless ext == "png"
  end

  def set_has_icon
    self.has_icon = true
  end

  def write_icon_file
    return if icon_file.blank?

    Danbooru.config.storage_manager.store_award_type_icon(icon_file, self)
  end

  def remove_icon_file
    Danbooru.config.storage_manager.delete_award_type_icon(id)
  end
end
