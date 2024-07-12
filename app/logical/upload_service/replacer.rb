# frozen_string_literal: true

class UploadService
  class Replacer
    attr_reader :post, :replacement

    def initialize(post:, replacement:)
      @post = post
      @replacement = replacement
    end

    def create_backup_replacement
      begin
        repl = post.replacements.new(creator_id: post.uploader_id, creator_ip_addr: post.uploader_ip_addr, status: 'original',
                                     image_width: post.image_width, image_height: post.image_height, file_ext: post.file_ext,
                                     file_size: post.file_size, md5: post.md5, file_name: "#{post.md5}.#{post.file_ext}",
                                     source: post.source, reason: 'Backup of original file', is_backup: true)
        repl.replacement_file = Danbooru.config.storage_manager.open(Danbooru.config.storage_manager.file_path(post, post.file_ext, :original))
        repl.save
      rescue Exception => e
        raise ProcessingError, "Failed to create post file backup: #{e.message}"
      end
      raise ProcessingError, "Could not create post file backup?" if !repl.valid?
    end

    def process!(penalize_current_uploader:)
      # Prevent trying to replace deleted posts
      raise ProcessingError, "Cannot replace post: post is deleted." if post.is_deleted?

      create_backup_replacement
      PostReplacement.transaction do
        replacement.replacement_file = Danbooru.config.storage_manager.open(Danbooru.config.storage_manager.replacement_path(replacement, replacement.file_ext, :original))

        upload = Upload.create(
          uploader_id: CurrentUser.id,
          uploader_ip_addr: CurrentUser.ip_addr,
          rating: post.rating,
          tag_string: (post.tag_array - PostReplacement::TAGS_TO_REMOVE_AFTER_ACCEPT).join(" "),
          source: replacement.source,
          file: replacement.replacement_file,
          replaced_post: post,
          original_post_id: post.id,
          replacement_id: replacement.id,
        )

        if upload.invalid? || upload.is_errored?
          raise ProcessingError, upload.errors.full_messages.to_sentence
        end

        begin
          upload.update(status: "processing")

          upload.file = Utils.get_file_for_upload(upload, file: upload.file)
          Utils.process_file(upload, upload.file, original_post_id: post.id)

          upload.save!
        rescue Exception => e
          upload.update(status: "error: #{e.class} - #{e.message}", backtrace: e.backtrace.join("\n"))
          raise ProcessingError, "#{e.class} - #{e.message}"
        end
        md5_changed = upload.md5 != post.md5

        # TODO: Fix this mess
        previous_uploader = post.uploader_id
        previous_md5 = post.md5
        previous_file_ext = post.file_ext

        post.md5 = upload.md5
        post.file_ext = upload.file_ext
        post.image_width = upload.image_width
        post.image_height = upload.image_height
        post.file_size = upload.file_size
        post.duration = upload.video_duration(upload.file.path)
        post.source = "#{replacement.source}\n" + post.source
        post.tag_string = upload.tag_string
        # Reset ownership information on post.
        post.uploader_id = replacement.creator_id
        post.uploader_ip_addr = replacement.creator_ip_addr
        post.save!

        # rescaling notes reloads the post, be careful when accessing previous values
        rescale_notes(post)

        replacement.update({
          status: 'approved',
          approver_id: CurrentUser.id,
          uploader_id_on_approve: previous_uploader,
          penalize_uploader_on_approve: penalize_current_uploader.to_s.truthy?
        })

        UserStatus.for_user(previous_uploader).update_all("own_post_replaced_count = own_post_replaced_count + 1")
        if penalize_current_uploader.to_s.truthy?
          UserStatus.for_user(previous_uploader).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count + 1")
        end

        # Everything went through correctly, the old files can now be removed
        if md5_changed
          Post.delete_files(post.id, previous_md5, previous_file_ext, force: true)
          post.generated_samples = nil
        end
      end
      if post.is_video?
        post.generate_video_samples(later: true)
      end

      post.update_iqdb_async
    end

    def rescale_notes(post)
      x_scale = post.image_width.to_f / post.image_width_before_last_save.to_f
      y_scale = post.image_height.to_f / post.image_height_before_last_save.to_f

      post.notes.each do |note|
        note.rescale!(x_scale, y_scale)
      end
    end
  end
end
