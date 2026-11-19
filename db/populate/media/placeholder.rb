# frozen_string_literal: true

require "tempfile"
require "tmpdir"

module Populate
  module Media
    # Writes flat-colour originals at each post's dimensions plus the previews and samples the
    # site expects, so imported posts render without their real files. Doc 44 tier 1.
    #
    # Image posts are thumbnailed in bulk with `vipsthumbnail` (one process per batch and
    # variant instead of several per post); videos go through ImageSampler one by one.
    class Placeholder < Base
      # Files are written no larger than this on the long side; the DB dimensions stay as exported.
      # A flat colour looks the same at any size, the browser scales the original to the stored
      # dimensions, and vipsthumbnail enlarges to fit, so previews and samples keep their real geometry
      # while the decode cost per post is negligible.
      SOURCE_MAX = 256
      BATCH_SIZE = 500
      JOB_SIZE = 64 # files per vipsthumbnail process, so large groups still spread across the pool
      # Encoder settings favour speed: a flat colour looks the same at any quality.
      JPEG_SUFFIX = "[Q=90,strip]"
      WEBP_SUFFIX = "[Q=75,effort=0]"

      # Same geometry as ImageSampler: previews scale the short side to 256 and crop the long side
      # beyond 512; samples scale the short side to 850 and shrink to fit 1700 on the long side.
      VARIANTS = {
        preview: { box: [512, 256], crop: true, when: ->(_post) { true } },
        sample: { box: [1700, 850], crop: false, when: ->(post) { !post.is_gif? && ([post.image_width, post.image_height].min > 850 || [post.image_width, post.image_height].max > 1700) } },
      }.freeze

      def call
        post_ids = options.fetch(:post_ids).map(&:to_i).uniq
        threads = options.fetch(:threads, Etc.nprocessors.clamp(2, 16))
        force = options.fetch(:force, false)

        ids = force ? post_ids : post_ids - Ledger.recorded(post_ids)
        log "* Placeholder media for #{ids.size} posts (#{threads} threads)"
        return { generated: 0, failed: 0 } if ids.empty?

        [ImageSampler, VipsCommand, ExternalCommand, FileMethods, Danbooru.config.storage_manager] # autoload on the main thread
        generated = 0
        failed = 0
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        ids.each_slice(BATCH_SIZE) do |batch_ids|
          posts = Post.where(id: batch_ids).to_a
          results = process_batch(posts, threads)
          failures = results.select { |_, error| error }
          failures.first(5).each { |post_id, error| log "    post ##{post_id}: #{error}" }
          Ledger.record(results.filter_map { |post_id, error| post_id if error.nil? }, "placeholder")

          generated += results.size - failures.size
          failed += failures.size
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          log "  #{generated + failed}/#{ids.size} (#{(generated / elapsed).round(1)}/s, #{failed} failed)"
        end

        { generated: generated, failed: failed }
      end

      # A flat original for one post, without previews (used when the previews came from elsewhere).
      def write_original(post)
        return if post.is_flash?

        storage = Danbooru.config.storage_manager
        file = build_file(post.md5, post.file_ext, post.image_width, post.image_height)
        storage.store(file, storage.post_file_path(post, :original))
      ensure
        file&.close!
      end

      # A flat file and thumbnail for an imported replacement; static1 only serves those with a signature.
      def write_replacement(replacement)
        return if replacement.file_ext == "swf"

        storage = Danbooru.config.storage_manager
        file = build_file(replacement.md5, replacement.file_ext, replacement.image_width, replacement.image_height)
        storage.store(file, storage.replacement_path(replacement, replacement.file_ext, :original))
        file.close!
        thumb = build_file(replacement.md5, "png", replacement.image_width, replacement.image_height) # thumbnails are always stills
        storage.store(thumb, storage.replacement_path(replacement, replacement.file_ext, :preview))
      ensure
        file&.close!
        thumb&.close!
      end

      private

      def process_batch(posts, threads)
        results = {}
        images, others = posts.partition(&:is_image?)
        videos = others.select(&:is_video?)
        (others - videos).each { |post| results[post.id] = nil } # flash: no file, no preview

        Dir.mktmpdir("placeholder") do |dir|
          results.merge!(process_images(images, dir, threads))
        end
        WorkerPool.each(videos, threads) { |post| generate_video(post) }.each { |post, error| results[post.id] = error }
        results.to_a
      end

      # Originals are written to disk once; every variant group is one vipsthumbnail run.
      def process_images(posts, dir, threads)
        results = {}
        storage = Danbooru.config.storage_manager
        sources = {}

        written = WorkerPool.each(posts, threads) do |post|
          path = File.join(dir, "#{post.md5}.png")
          width, height = source_size(post)
          File.open(path, "wb") { |file| FlatPng.write(file, width: width, height: height, rgb: FlatPng.colour_for(post.md5)) }
          File.open(path, "rb") { |file| storage.store(file, storage.post_file_path(post, :original)) }
        end
        written.each do |post, error|
          results[post.id] = error
          sources[post] = File.join(dir, "#{post.md5}.png") if error.nil?
        end

        jobs = []
        VARIANTS.each do |variant, rule|
          wanted = sources.keys.select { |post| results[post.id].nil? && rule[:when].call(post) }
          wanted.group_by { |post| geometry(post, rule) }.each do |(size, crop), group|
            group.each_slice(JOB_SIZE) { |chunk| %w[jpg webp].each { |ext| jobs << [variant, ext, size, crop, chunk] } }
          end
        end

        outcomes = WorkerPool.each(jobs, threads) do |variant, ext, size, crop, group|
          out_dir = File.join(dir, [variant, ext, size, ("crop" if crop)].compact.join("_"))
          FileUtils.mkdir_p(out_dir)
          thumbnail_all(group.map { |post| sources[post] }, out_dir, ext, size, crop)
          group.each do |post|
            File.open(File.join(out_dir, "#{post.md5}.#{ext}"), "rb") { |file| storage.store(file, storage.post_file_path(post, :"#{variant}_#{ext}")) }
          end
        end
        outcomes.each do |(_variant, _ext, _size, _crop, group), error|
          group.each { |post| results[post.id] ||= error } if error
        end

        results
      end

      # Previews and samples follow the stored dimensions, not the capped file.
      def geometry(post, rule)
        width = [post.image_width.to_i, 1].max
        height = [post.image_height.to_i, 1].max
        box = width >= height ? rule[:box] : rule[:box].reverse
        long, short = width >= height ? [width, height] : [height, width]
        # Wider than 2:1 gets cropped to the box; everything else fits inside it with the short side filled.
        crop = rule[:crop] && long * box.min > short * box.max
        ["#{box[0]}x#{box[1]}", crop]
      end

      def thumbnail_all(paths, out_dir, ext, size, crop)
        suffix = ext == "jpg" ? JPEG_SUFFIX : WEBP_SUFFIX
        # No colour management: the sources are flat sRGB and the ICC transform costs more than the resize.
        # Several of these run at once, so each gets a couple of vips threads rather than every core.
        args = ["--size", size, "--vips-concurrency", "2", "--path", "#{out_dir}/%s.#{ext}#{suffix}"]
        args += ["--smartcrop", "entropy"] if crop
        _stdout, stderr, status = ExternalCommand.run("vipsthumbnail", *args, *paths, timeout: 600, cpu: 1200)
        raise Error, "vipsthumbnail failed: #{stderr.to_s.lines.last.to_s.strip}" unless status.success?
      end

      def generate_video(post)
        storage = Danbooru.config.storage_manager
        file = build_file(post.md5, post.file_ext, post.image_width, post.image_height)
        begin
          storage.store(file, storage.post_file_path(post, :original))
        ensure
          file.close!
        end
        ImageSampler.generate_post_images(post)
      end

      # A flat PNG for images, or a one-second flat clip in the right container for videos.
      def build_file(md5, file_ext, width, height)
        width, height = source_size_for(width, height)
        rgb = FlatPng.colour_for(md5)
        return flat_png(width, height, rgb) unless FileMethods::VIDEO_FILE_TYPES.include?(file_ext)

        width -= width % 2
        height -= height % 2
        file = Tempfile.new(["placeholder", ".#{file_ext}"], binmode: true)
        codec = file_ext == "webm" ? %w[-c:v libvpx -b:v 200k] : %w[-c:v libx264 -pix_fmt yuv420p -preset ultrafast]
        colour = "0x#{rgb.map { |c| c.to_s(16).rjust(2, '0') }.join}"
        _stdout, stderr, status = ExternalCommand.run(
          Danbooru.config.ffmpeg_path, "-y", "-f", "lavfi", "-i", "color=c=#{colour}:s=#{width}x#{height}:d=1:r=10",
          *codec, "-threads", "1", file.path, timeout: 60
        )
        raise Error, "ffmpeg failed: #{stderr.to_s.lines.last.to_s.strip}" unless status.success?

        file.rewind
        file
      end

      def flat_png(width, height, rgb)
        file = Tempfile.new(["placeholder", ".png"], binmode: true)
        FlatPng.write(file, width: width, height: height, rgb: rgb)
        file.rewind
        file
      end

      def source_size(post)
        source_size_for(post.image_width, post.image_height)
      end

      def source_size_for(width, height)
        width = [width.to_i, 1].max
        height = [height.to_i, 1].max
        scale = [SOURCE_MAX.to_f / [width, height].max, 1.0].min
        [[(width * scale).round, 2].max, [(height * scale).round, 2].max]
      end

      class Error < StandardError; end
    end
  end
end
