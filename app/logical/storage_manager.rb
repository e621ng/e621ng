class StorageManager
  class Error < StandardError; end

  DEFAULT_BASE_DIR = "#{Rails.root}/public/data"

  attr_reader :base_url, :base_dir, :hierarchical, :tagged_filenames, :large_image_prefix, :base_url_protected, :base_dir_protected

  def initialize(base_url: default_base_url, base_dir: DEFAULT_BASE_DIR, hierarchical: false,
                 tagged_filenames: Danbooru.config.enable_seo_post_urls, large_image_prefix: Danbooru.config.large_image_prefix,
                 protected_prefix: Danbooru.config.protected_path_prefix)
    @base_url = base_url.chomp("/")
    @base_url_protected = "#{@base_url}/#{protected_prefix}"
    @base_dir = base_dir
    @base_dir_protected = "#{@base_dir}/#{protected_prefix}"
    @hierarchical = hierarchical
    @tagged_filenames = tagged_filenames
    @large_image_prefix = large_image_prefix
  end

  def default_base_url
    "#{CurrentUser.root_url}/data"
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

  def delete_file(post_id, md5, file_ext, type)
    delete(file_path(md5, file_ext, type))
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

  def protected_params(url, post)
    user_id = CurrentUser.id
    ip = CurrentUser.ip_addr
    time = (Time.now + 15.minute).to_i
    secret = Danbooru.config.protected_file_secret
    hmac = Digest::MD5.base64digest("#{time} #{url} #{user_id} #{secret}").tr("+/","-_").gsub("==",'')
    "?auth=#{hmac}&expires=#{time}&uid=#{user_id}"
  end

  def file_url(post, type, tagged_filenames: false)
    subdir = subdir_for(post.md5)
    file = file_name(post.md5, post.file_ext, type)
    seo_tags = seo_tags(post) if tagged_filenames
    base = post.protect_file? ? base_url_protected : base_url

    url = if type == :preview && !post.has_preview?
      "#{root_url}/images/download-preview.png"
    elsif type == :preview
      "#{base}/preview/#{subdir}#{file}"
    elsif type == :crop
      "#{base}/crop/#{subdir}#{file}"
    elsif type == :large && post.has_large?
      "#{base}/sample/#{subdir}#{seo_tags}#{file}"
    else
      "#{base}/#{subdir}#{seo_tags}#{post.md5}.#{post.file_ext}"
    end
    if post.protect_file?
      "#{url}#{protected_params(url, post)}" if post.protect_file?
    else
      url
    end
  end

  def root_url
    origin = Addressable::URI.parse(base_url).origin
    origin = "" if origin == "null" # base_url was relative
    origin
  end

  def file_path(post_or_md5, file_ext, type, protected=false)
    md5 = post_or_md5.is_a?(String) ? post_or_md5 : post_or_md5.md5
    subdir = subdir_for(md5)
    file = file_name(md5, file_ext, type)
    base = protected ? base_dir_protected : base_dir

    case type
    when :preview
      "#{base}/preview/#{subdir}#{file}"
    when :crop
      "#{base}/crop/#{subdir}#{file}"
    when :large
      "#{base}/sample/#{subdir}#{file}"
    when :original
      "#{base}/#{subdir}#{file}"
    end
  end

  def file_name(md5, file_ext, type)
    large_file_ext = (file_ext == "zip") ? "webm" : "jpg"

    case type
    when :preview
      "#{md5}.jpg"
    when :crop
      "#{md5}.jpg"
    when :large
      "#{large_image_prefix}#{md5}.#{large_file_ext}"
    when :original
      "#{md5}.#{file_ext}"
    end
  end

  def subdir_for(md5)
    hierarchical ? "#{md5[0..1]}/#{md5[2..3]}/" : ""
  end

  def seo_tags(post)
    return "" if !tagged_filenames

    tags = post.presenter.humanized_essential_tag_string.gsub(/[^a-z0-9]+/, "_").gsub(/(?:^_+)|(?:_+$)/, "").gsub(/_{2,}/, "_")
    "__#{tags}__"
  end
end
