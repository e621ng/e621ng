# frozen_string_literal: true

class StorageManager
  class Error < StandardError; end

  DEFAULT_BASE_DIR = "#{Rails.root}/public/data"
  IMAGE_TYPES = %i[preview_jpg preview_webp sample_jpg sample_webp original].freeze
  MASCOT_PREFIX = "mascots"

  attr_reader :base_url, :base_dir, :hierarchical, :large_image_prefix, :protected_prefix, :base_path, :replacement_prefix

  def initialize(base_url: default_base_url, base_path: default_base_path, base_dir: DEFAULT_BASE_DIR, hierarchical: false,
                 large_image_prefix: Danbooru.config.large_image_prefix,
                 protected_prefix: Danbooru.config.protected_path_prefix,
                 replacement_prefix: Danbooru.config.replacement_path_prefix)
    @base_url = base_url.chomp("/")
    @base_dir = base_dir
    @base_path = base_path
    @protected_prefix = protected_prefix
    @replacement_prefix = replacement_prefix
    @hierarchical = hierarchical
    @large_image_prefix = large_image_prefix
  end

  def default_base_path
    "/data"
  end

  def default_base_url
    return "" if Rails.env.development?

    Rails.application.routes.url_helpers.root_url
  end

  # Store the given file at the given path. If a file already exists at that
  # location it should be overwritten atomically. Either the file is fully
  # written, or an error is raised and the original file is left unchanged. The
  # file should never be in a partially written state.
  def store(io, path)
    raise NotImplementedError, "store not implemented"
  end

  # Delete the file at the given path. If the file doesn't exist, no error
  # should be raised.
  def delete(path)
    raise NotImplementedError, "delete not implemented"
  end

  # Return a readonly copy of the file located at the given path.
  def open(path)
    raise NotImplementedError, "open not implemented"
  end

  def store_file(io, post, type)
    store(io, file_path(post.md5, post.file_ext, type))
  end

  def store_replacement(io, replacement, image_size)
    store(io, replacement_path(replacement.storage_id, replacement.file_ext, image_size))
  end

  def delete_file(post_id, md5, file_ext, type, scale_factor: nil)
    delete(file_path(md5, file_ext, type, scale: scale_factor))
    delete(file_path(md5, file_ext, type, scale: scale_factor, protect: true))
  end

  def delete_post_files(post_or_md5, file_ext)
    md5 = post_or_md5.is_a?(String) ? post_or_md5 : post_or_md5.md5
    IMAGE_TYPES.each do |type|
      delete(file_path(md5, file_ext, type, protect: false))
      delete(file_path(md5, file_ext, type, protect: true))
    end

    delete_video_samples(md5)
  end

  def delete_crop_file(md5)
    delete(file_path(md5, "jpg", :crop, protect: false))
    delete(file_path(md5, "jpg", :crop, protect: true))
  end

  def delete_video_samples(post_or_md5)
    md5 = post_or_md5.is_a?(String) ? post_or_md5 : post_or_md5.md5

    # Delete variants
    delete file_path(md5, "mp4", :scaled, scale: "alt", protect: true)
    delete file_path(md5, "mp4", :scaled, scale: "alt", protect: false)

    # Delete sampled videos
    Danbooru.config.video_samples.each_key do |scale|
      delete file_path(md5, "mp4", :scaled, scale: scale, protect: true)
      delete file_path(md5, "mp4", :scaled, scale: scale, protect: false)
    end
  end

  def delete_replacement(replacement)
    delete(replacement_path(replacement.storage_id, replacement.file_ext, :original))
    delete(replacement_path(replacement.storage_id, replacement.file_ext, :preview))
  end

  def open_file(post, type)
    open(file_path(post.md5, post.file_ext, type))
  end

  def move_file_delete(post)
    raise NotImplementedError, "move_file_delete not implemented"
  end

  def move_file_undelete(post)
    raise NotImplementedError, "move_file_undelete not implemented"
  end

  def replacement_url(replacement, image_size = :original)
    subdir = subdir_for(replacement.storage_id)
    file = "#{replacement.storage_id}#{'_thumb' if image_size == :preview}.#{replacement.file_ext}"
    base = "#{base_path}/#{replacement_prefix}"
    path = "#{base}/#{subdir}#{file}"
    "#{base_url}#{path}#{protected_params(path, secret: Danbooru.config.replacement_file_secret)}"
  end

  def root_url
    origin = Addressable::URI.parse(base_url).origin
    origin = "" if origin == "null" # base_url was relative
    origin
  end

  def file_name(md5, file_ext, type, scale_factor: nil)
    case type
    when :preview, :crop
      "#{md5}.#{file_ext || 'jpg'}"
    when :large
      "#{large_image_prefix}#{md5}.jpg"
    when :original
      "#{md5}.#{file_ext}"
    when :scaled
      "#{md5}_#{scale_factor}.#{file_ext}"
    end
  end

  def replacement_path(replacement_or_storage_id, file_ext, image_size)
    storage_id = replacement_or_storage_id.is_a?(String) ? replacement_or_storage_id : replacement_or_storage_id.storage_id
    subdir = subdir_for(storage_id)
    file = "#{storage_id}#{'_thumb' if image_size == :preview}.#{file_ext}"
    "#{base_dir}/#{replacement_prefix}/#{subdir}#{file}"
  end

  def store_mascot(io, mascot)
    store(io, mascot_path(mascot.md5, mascot.file_ext))
  end

  def mascot_path(md5, file_ext)
    file = "#{md5}.#{file_ext}"
    "#{base_dir}/#{MASCOT_PREFIX}/#{file}"
  end

  def mascot_url(mascot)
    file = "#{mascot.md5}.#{mascot.file_ext}"
    "#{base_url}#{base_path}/#{MASCOT_PREFIX}/#{file}"
  end

  def delete_mascot(md5, file_ext)
    delete(mascot_path(md5, file_ext))
  end

  def furids_url
    "#{base_url}#{base_path}/furid/"
  end

  #########################
  ### File Path Methods ###
  #########################

  def file_path(md5, file_ext, type = :original, protect: false, scale: nil)
    "#{base_dir}#{file_path_base(md5, file_ext, type, protect: protect, scale: scale)}"
  end

  def post_file_path(post, type = :original, ext: nil, protect: nil, scale: nil)
    if %i[preview preview_jpg preview_webp].include?(type) && !post.has_preview?
      return "/images/download-preview.png"
    end
    ext = post.file_ext if ext.nil?
    protect = post.protect_file? if protect.nil?
    file_path(post.md5, ext, type, protect: protect, scale: scale)
  end

  def file_url(md5, file_ext, type = :original, protect: false, scale: nil)
    path = file_path_base(md5, file_ext, type, protect: protect, scale: scale)
    if protect
      "#{base_url}#{base_path}#{path}#{protected_params(base_path + path)}"
    else
      "#{base_url}#{base_path}#{path}"
    end
  end

  def post_file_url(post, type = :original, ext: nil, scale: nil)
    if %i[preview preview_jpg preview_webp].include?(type) && !post.has_preview?
      return "/images/download-preview.png"
    end
    ext ||= post.file_ext
    file_url(post.md5, ext, type, protect: post.protect_file?, scale: scale)
  end

  def file_path_base(md5, file_ext, type = :original, protect: false, scale: nil)
    subdir = subdir_for(md5)
    base = protect ? "/#{protected_prefix}" : ""

    if type == :original
      path = "#{base}/#{subdir}#{md5}.#{file_ext}"
    elsif %i[preview_jpg preview].include?(type) # compatibility
      path = "#{base}/preview/#{subdir}#{md5}.jpg"
    elsif type == :preview_webp
      path = "#{base}/preview/#{subdir}#{md5}.webp"
    elsif %i[sample_jpg sample large].include?(type) # compatibility
      path = "#{base}/sample/#{subdir}#{md5}.jpg"
    elsif type == :sample_webp
      path = "#{base}/sample/#{subdir}#{md5}.webp"
    elsif type == :scaled && scale.present?
      path = "#{base}/sample/#{subdir}#{md5}_#{scale}.mp4"
    elsif type == :crop
      path = "#{base}/crop/#{subdir}#{md5}.jpg" # compatibility
    else
      raise Error, "Unknown file type '#{type}' for #{md5}.#{file_ext}"
    end

    path
  end

  #########################
  ### File Path Helpers ###
  #########################

  def subdir_for(md5)
    hierarchical ? "#{md5[0..1]}/#{md5[2..3]}/" : ""
  end

  def protected_params(url, secret: Danbooru.config.protected_file_secret)
    user_id = CurrentUser.id
    time = (Time.now + 15.minutes).to_i
    hmac = Digest::MD5.base64digest("#{time} #{url} #{user_id} #{secret}").tr("+/", "-_").gsub("==", "")
    "?auth=#{hmac}&expires=#{time}&uid=#{user_id}"
  end
end
