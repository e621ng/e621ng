# frozen_string_literal: true

class StorageManager::Local < StorageManager
  DEFAULT_PERMISSIONS = 0644

  def store(io, dest_path)
    temp_path = "#{dest_path}-#{SecureRandom.uuid}.tmp"

    FileUtils.mkdir_p(File.dirname(temp_path))
    io.rewind
    bytes_copied = IO.copy_stream(io, temp_path)
    raise Error, "store failed: #{bytes_copied}/#{io.size} bytes copied" if bytes_copied != io.size

    FileUtils.chmod(DEFAULT_PERMISSIONS, temp_path)
    File.rename(temp_path, dest_path)
  rescue StandardError => e
    FileUtils.rm_f(temp_path)
    raise Error, e
  ensure
    FileUtils.rm_f(temp_path) if temp_path
  end

  def delete(path)
    FileUtils.rm_f(path)
  end

  def open(path)
    File.open(path, "r", binmode: true)
  end

  def move_file_delete(post)
    IMAGE_TYPES.each do |type|
      path = post_file_path(post, type, protect: false)
      new_path = post_file_path(post, type, protect: true)
      move_file(path, new_path)
    end
    return unless post.is_video?

    # Move variants
    post.video_sample_list[:variants].each_key do
      path = post_file_path(post, :scaled, scale: "alt", protect: false)
      new_path = post_file_path(post, :scaled, scale: "alt", protect: true)
      move_file(path, new_path)
    end

    # Move sampled videos
    Danbooru.config.video_samples.each_key do |scale|
      path = post_file_path(post, :scaled, scale: scale, protect: false)
      new_path = post_file_path(post, :scaled, scale: scale, protect: true)
      move_file(path, new_path)
    end
  end

  def move_file_undelete(post)
    IMAGE_TYPES.each do |type|
      path = post_file_path(post, type, protect: true)
      new_path = post_file_path(post, type, protect: false)
      move_file(path, new_path)
    end
    return unless post.is_video?

    # Move variants
    post.video_sample_list[:variants].each_key do
      path = post_file_path(post, :scaled, scale: "alt", protect: true)
      new_path = post_file_path(post, :scaled, scale: "alt", protect: false)
      move_file(path, new_path)
    end

    # Move sampled videos
    Danbooru.config.video_samples.each_key do |scale|
      path = post_file_path(post, :scaled, scale: scale, protect: true)
      new_path = post_file_path(post, :scaled, scale: scale, protect: false)
      move_file(path, new_path)
    end
  end

  private

  def move_file(old_path, new_path)
    if File.exist?(old_path)
      FileUtils.mkdir_p(File.dirname(new_path))
      FileUtils.mv(old_path, new_path)
      FileUtils.chmod(DEFAULT_PERMISSIONS, new_path)
    end
  end
end
