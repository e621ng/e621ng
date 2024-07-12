# frozen_string_literal: true

class Mascot < ApplicationRecord
  belongs_to_creator

  array_attribute :available_on, parse: /[^,]+/, join_character: ","
  attr_accessor :mascot_file

  validates :display_name, :background_color, :artist_url, :artist_name, presence: true
  validates :artist_url, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }
  validates :mascot_file, presence: true, on: :create
  validate :set_file_properties
  validates :md5, uniqueness: true
  validate if: :mascot_file do |mascot|
    max_file_sizes = { "jpg" => 500.kilobytes, "png" => 500.kilobytes }
    FileValidator.new(mascot, mascot_file.path).validate(max_file_sizes: max_file_sizes, max_width: 1_000, max_height: 1_000)
  end

  after_commit :invalidate_cache
  after_save_commit :write_storage_file
  after_destroy_commit :remove_storage_file

  def set_file_properties
    return if mascot_file.blank?

    self.file_ext = file_header_to_file_ext(mascot_file.path)
    self.md5 = Digest::MD5.file(mascot_file.path).hexdigest
  end

  def write_storage_file
    return if mascot_file.blank?

    Danbooru.config.storage_manager.delete_mascot(md5_previously_was, file_ext_previously_was)
    Danbooru.config.storage_manager.store_mascot(mascot_file, self)
  end

  def self.active_for_browser
    Cache.fetch("active_mascots", expires_in: 1.day) do
      query = Mascot.where(active: true).where("? = ANY(available_on)", Danbooru.config.app_name)
      mascots = query.map do |mascot|
        mascot.slice(:id, :background_color, :artist_url, :artist_name).merge(background_url: mascot.url_path)
      end
      mascots.index_by { |mascot| mascot["id"] }
    end
  end

  def invalidate_cache
    Cache.delete("active_mascots")
  end

  def remove_storage_file
    Danbooru.config.storage_manager.delete_mascot(md5, file_ext)
  end

  def url_path
    Danbooru.config.storage_manager.mascot_url(self)
  end

  def file_path
    Danbooru.config.storage_manager.mascot_path(self)
  end

  concerning :ValidationMethods do
    def dimensions
      @dimensions ||= calculate_dimensions(mascot_file.path)
    end

    def image_width
      dimensions[0]
    end

    def image_height
      dimensions[1]
    end

    def file_size
      @file_size ||= Danbooru.config.storage_manager.open(mascot_file.path).size
    end
  end

  def self.search(params)
    q = super
    q.order("lower(artist_name)")
  end

  def method_attributes
    super + [:url_path]
  end

  include FileMethods
end
