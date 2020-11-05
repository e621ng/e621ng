class UploadService
  module Utils
    extend self
    class CorruptFileError < RuntimeError; end

    IMAGE_TYPES = %i[original large preview crop]

    def file_header_to_file_ext(file)
      case File.read(file.path, 16)
      when /^\xff\xd8/n
        "jpg"
      when /^GIF87a/, /^GIF89a/
        "gif"
      when /^\x89PNG\r\n\x1a\n/n
        "png"
      when /^\x1a\x45\xdf\xa3/n
        "webm"
      # when /^PK\x03\x04/
      #   "zip"
      else
        "bin"
      end
    end

    def delete_file(md5, file_ext, upload_id = nil)
      if Post.where(md5: md5).exists?
        if upload_id.present? && Upload.where(id: upload_id).exists?
          CurrentUser.as_system do
            Upload.find(upload_id).update(status: "completed")
          end
        end

        return
      end

      if upload_id.present? && Upload.where(id: upload_id).exists?
        CurrentUser.as_system do
          Upload.find(upload_id).update(status: "preprocessed + deleted")
        end
      end
      
      Danbooru.config.storage_manager.delete_post_files(md5, file_ext)
    end

    def calculate_ugoira_dimensions(source_path)
      folder = Zip::File.new(source_path)
      Tempfile.open("ugoira-dim-") do |tempfile|
        folder.first.extract(tempfile.path) { true }
        image_size = ImageSpec.new(tempfile.path)
        return [image_size.width, image_size.height]
      end
    end

    def calculate_dimensions(upload, file)
      if upload.is_video?
        video = FFMPEG::Movie.new(file.path)
        yield(video.width, video.height)

      elsif upload.is_ugoira?
        w, h = calculate_ugoira_dimensions(file.path)
        yield(w, h)

      elsif upload.is_image?
        image_size = ImageSpec.new(file.path)
        yield(image_size.width, image_size.height)

      elsif upload.file_ext == "bin"
        yield(0, 0)

      else
        raise ArgumentError, "unhandled file type (#{upload.file_ext})" # should not happen
      end
    end

    def distribute_files(file, record, type, original_post_id: nil)
      # need to do this for hybrid storage manager
      post = Post.new
      post.id = original_post_id if original_post_id.present?
      post.md5 = record.md5
      post.file_ext = record.file_ext
      [Danbooru.config.storage_manager, Danbooru.config.backup_storage_manager].each do |sm|
        sm.store_file(file, post, type)
      end
    end

    def is_downloadable?(source)
      source =~ /^https?:\/\//
    end

    def generate_resizes(file, upload)
      if upload.is_ugoira?
        preview_file = PixivUgoiraConverter.generate_preview(file)
        crop_file = PixivUgoiraConverter.generate_crop(file)
        sample_file = PixivUgoiraConverter.generate_webm(file, upload.context["ugoira"]["frame_data"])
        [preview_file, crop_file, sample_file]
      else
        PostThumbnailer.generate_resizes(file, upload.image_height, upload.image_width, upload.is_video? ? :video : :image)
      end
    end

    def process_file(upload, file, original_post_id: nil)
      upload.file = file
      upload.file_ext = Utils.file_header_to_file_ext(file)
      upload.file_size = file.size
      upload.md5 = Digest::MD5.file(file.path).hexdigest

      Utils.calculate_dimensions(upload, file) do |width, height|
        upload.image_width = width
        upload.image_height = height
      end

      upload.is_apng = is_animated_png?(upload, file)

      upload.validate!(:file)
      upload.tag_string = "#{upload.tag_string} #{Utils.automatic_tags(upload, file)}"

      preview_file, crop_file, sample_file = Utils.generate_resizes(file, upload)

      begin
        Utils.distribute_files(file, upload, :original, original_post_id: original_post_id)
        Utils.distribute_files(sample_file, upload, :large, original_post_id: original_post_id) if sample_file.present?
        Utils.distribute_files(preview_file, upload, :preview, original_post_id: original_post_id) if preview_file.present?
        Utils.distribute_files(crop_file, upload, :crop, original_post_id: original_post_id) if crop_file.present?
      ensure
        preview_file.try(:close!)
        crop_file.try(:close!)
        sample_file.try(:close!)
      end

      # in case this upload never finishes processing, we need to delete the
      # distributed files in the future
      UploadDeleteFilesJob.set(wait: 24.hours).perform_later(upload.md5, upload.file_ext, upload.id)
    end

    # these methods are only really used during upload processing even
    # though logically they belong on upload. post can rely on the
    # automatic tag that's added.
    def is_animated_gif?(upload, file)
      return false if upload.file_ext != "gif"

      # Check whether the gif has multiple frames by trying to load the second frame.
      result = Vips::Image.gifload(file.path, page: 1) rescue $ERROR_INFO
      if result.is_a?(Vips::Image)
        true
      elsif result.is_a?(Vips::Error) && result.message =~ /bad page number/
        false
      else
        raise result
      end
    end

    def is_animated_png?(upload, file)
      upload.file_ext == "png" && ApngInspector.new(file.path).inspect!.animated?
    end

    def is_video_with_audio?(upload, file)
      return false if !upload.is_video? # avoid ffprobe'ing the file if it's not a video (issue #3826)
      video = FFMPEG::Movie.new(file.path)
      video.audio_channels.present?
    end

    def automatic_tags(upload, file)
      return "" unless Danbooru.config.enable_dimension_autotagging

      tags = []
      tags += ["animated_gif", "animated"] if is_animated_gif?(upload, file)
      tags += ["animated_png", "animated"] if is_animated_png?(upload, file)
      tags.join(" ")
    end

    def get_file_for_upload(upload, file: nil)
      return file if file.present?
      raise RuntimeError, "No file or source URL provided" if upload.direct_url_parsed.blank?

      download = Downloads::File.new(upload.direct_url_parsed, upload.referer_url)
      file, strategy = download.download!

      if download.data[:ugoira_frame_data].present?
        upload.context = {
          "ugoira" => {
            "frame_data" => download.data[:ugoira_frame_data],
            "content_type" => "image/jpeg"
          }
        }
      end

      return file
    end
  end
end
